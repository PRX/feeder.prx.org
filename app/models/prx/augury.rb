module Prx
  class Augury
    include Prx::Api
    API_PATH = "/api/v1"

    attr_accessor :enabled, :root, :expiration

    def initialize(options = {})
      @expiration = (options[:expiration] || 1.minute).to_i
      @root = options[:root] || augury_root
      @enabled = @root.present?
    end

    def placements(podcast_id, options = {})
      return nil unless ENV["AUGURY_HOST"].present?
      path = "#{API_PATH}/podcasts/#{podcast_id}/placements"
      expires = (options[:expiration] || expiration).to_i
      Rails.cache.fetch(path, expires_in: expires) { get(root, path) }
    end

    def get(root, path)
      api(root: root, account: "*").tap { |a| a.href = path }.get
    rescue HyperResource::ClientError, HyperResource::ServerError, NotImplementedError => e
      unless e.message == "404"
        Rails.logger.error("Error: GET #{path}", error: e.message)
      end
      nil
    end
  end
end
