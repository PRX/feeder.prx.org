module PRX
  class Augury
    include Prx::Api
    API_PATH = "/api/v1"

    attr_accessor :enabled, :root, :expiration

    def initialize(options = {})
      @expiration = (options[:expiration] || 1.minute).to_i
      @root = options[:root] || augury_root
      @enabled = @root.present?
    end

    def placements(podcast, options = {})
      path = "#{API_PATH}/podcasts/#{podcast.id}/placements"
      expires = (options[:expiration] || expiration).to_i
      Rails.cache.fetch(path, expires_in: expires) { get(root, path) }
    end

    def get(root, path)
      api(root: root, account: "*").tap { |a| a.href = path }.get
    rescue HyperResource::ClientError, HyperResource::ServerError, NotImplementedError => e
      Rails.logger.error("Error: GET #{path}", error: e.message)
      nil
    end
  end
end
