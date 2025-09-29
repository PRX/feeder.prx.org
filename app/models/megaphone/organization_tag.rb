module Megaphone
  class OrganizationTag
    include Megaphone::Model

    ALL_ATTRIBUTES = %i[label value podcast_count episode_count]

    attr_accessor(*ALL_ATTRIBUTES)

    def self.list_by_feed(feed)
      ot = OrganizationTag.new
      ot.config = feed.config
      ot.list
    end

    def list
      self.api_response = api.get_base("organizations/#{config.organization_id}/tags")
      handle_response(api_response)
    end

    def handle_response(response)
      response[:items].map { |item| OrganizationTag.new(item.slice(*ALL_ATTRIBUTES)) }
    end
  end
end
