module Apple
  class EpisodeDeliveryStatus < Integrations::EpisodeDeliveryStatus
    # TODO: enable once writers are cut over and the AppleShowBackfill has
    # stamped all legacy rows (S10)
    # validates :apple_show_id, presence: true

    def self.sti_name
      "apple"
    end

    # The current status for an episode within a single Apple show. Reads are
    # strictly scoped: rows stamped with another show (or the pre-show-scoping
    # NULL stamp) are not visible here.
    def self.current(episode, apple_show_id:)
      where(episode_id: episode.id, apple_show_id: apple_show_id)
        .order(created_at: :desc)
        .first
    end

    def self.current_or_default(episode, apple_show_id:)
      current(episode, apple_show_id: apple_show_id) ||
        default_status(episode, apple_show_id: apple_show_id)
    end

    def self.default_status(episode, apple_show_id:)
      new(episode: episode, apple_show_id: apple_show_id)
    end

    def self.update_status(episode, attrs, apple_show_id:)
      new_status = current(episode, apple_show_id: apple_show_id)&.dup ||
        default_status(episode, apple_show_id: apple_show_id)
      new_status.assign_attributes(attrs.merge(apple_show_id: apple_show_id))
      new_status.save!
      episode.episode_delivery_statuses.reset
      new_status
    end

    private

    def update_status(attrs)
      self.class.update_status(episode, attrs, apple_show_id: apple_show_id)
    end
  end
end
