module Megaphone
  class Episode < Megaphone::Model
    attr_accessor :episode

    # Required attributes for a create
    # external_id is not required by megaphone, but we need it to be set!
    CREATE_REQUIRED = %w[title external_id]

    # All other attributes we might expect back from the Megaphone API
    # (some documented, others not so much)
    OTHER_ATTRIBUTES = %w[id created_at updated_at]

    DEPRECATED = %w[]

    ALL_ATTRIBUTES = (CREATE_REQUIRED + DEPRECATED + OTHER_ATTRIBUTES)

    attr_accessor(*ALL_ATTRIBUTES)

    validates_presence_of CREATE_REQUIRED

    validates_presence_of :id, on: :update

    validates_absence_of :id, on: :create

    def self.new_from_episode(dt_episode, feed = nil)
      episode = Megaphone::Episode.new(attributes_from_episode(dt_episode))
      episode.episode = dt_episode
      episode.feed = feed
      episode
    end

    def self.attributes_from_episode(dte)
      {
        title: dte.title,
        external_id: dte.guid
      }
    end
  end
end
