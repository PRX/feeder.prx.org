module Apple
  class EpisodeDeliveryStatus < Integrations::EpisodeDeliveryStatus
    validates :apple_show_id, presence: true

    def self.sti_name
      "apple"
    end

    def self.current(episode, apple_show_id:)
      apple_show_id = scoped_apple_show_id!(apple_show_id)
      statuses = where(episode_id: episode.id).order(created_at: :desc)
      statuses.find_by(apple_show_id: apple_show_id)
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
      apple_show_id.presence || raise(MissingShowIdentityError, "Apple delivery state requires an Apple show ID")
    end
    private_class_method :scoped_apple_show_id!
  end
end
