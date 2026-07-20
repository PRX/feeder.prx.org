module Apple
  class EpisodeDeliveryStatus < Integrations::EpisodeDeliveryStatus
    # During the transition, existing NULL-show rows must remain loadable and
    # saveable long enough to be backfilled. New rows must always be scoped.
    # TODO remove with cutover: validate every row and add the database constraint.
    validates :apple_show_id, presence: true, on: :create

    def self.sti_name
      "apple"
    end

    undef_method :increment_asset_wait,
      :mark_as_uploaded!,
      :mark_as_not_uploaded!,
      :mark_as_delivered!,
      :mark_as_not_delivered!,
      :update_status

    # A known show may temporarily read the latest legacy NULL-show row. A
    # subsequent update duplicates it into a new row stamped with this show.
    # TODO remove with cutover after all legacy NULL-show rows are stamped.
    def self.current(episode, apple_show_id:)
      apple_show_id = scoped_apple_show_id!(apple_show_id)
      statuses = where(episode_id: episode.id).order(created_at: :desc)
      statuses.find_by(apple_show_id: apple_show_id) || statuses.find_by(apple_show_id: nil)
    end

    def self.current_or_default(episode, apple_show_id:)
      current(episode, apple_show_id: apple_show_id) ||
        default_status(episode, apple_show_id: apple_show_id)
    end

    def self.default_status(episode, apple_show_id:)
      new(episode: episode, apple_show_id: scoped_apple_show_id!(apple_show_id))
    end

    def self.update_status(episode, attrs, apple_show_id:)
      apple_show_id = scoped_apple_show_id!(apple_show_id)
      new_status = current(episode, apple_show_id: apple_show_id)&.dup ||
        default_status(episode, apple_show_id: apple_show_id)
      new_status.assign_attributes(attrs.merge(apple_show_id: apple_show_id))
      new_status.save!
      episode.episode_delivery_statuses.reset
      new_status
    end

    def self.scoped_apple_show_id!(apple_show_id)
      apple_show_id.presence || raise(ArgumentError, "Apple delivery state requires an Apple show ID")
    end
    private_class_method :scoped_apple_show_id!
  end
end
