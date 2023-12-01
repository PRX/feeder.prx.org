class Authorization
  API_ADMIN_CACHE_KEY = "api-admin"

  include HalApi::RepresentedModel

  attr_accessor :token, :api_admin

  def initialize(prx_auth_token, has_api_admin_token = false)
    @token = prx_auth_token
    @api_admin = has_api_admin_token
  end

  def user_id
    token&.user_id
  end

  def to_model
    self
  end

  def persisted?
    false
  end

  def cache_key
    token_key =
      if api_admin
        API_ADMIN_CACHE_KEY
      else
        OpenSSL::Digest::MD5.hexdigest([token.scopes, token.resources].map(&:to_s).join(""))
      end

    ActiveSupport::Cache.expand_cache_key(["PRX::Authorization", token_key])
  end

  def globally_authorized?
    api_admin || token.globally_authorized?("read-private")
  end

  def token_auth_account_ids
    token&.resources(:read_private) || []
  end

  def token_auth_account_uris
    token_auth_account_ids.map { |id| "/api/v1/accounts/#{id}" }
  end

  def token_auth_podcasts
    if globally_authorized?
      Podcast.all
    else
      Podcast.where(prx_account_uri: token_auth_account_uris)
    end
  end

  def token_auth_feeds
    if globally_authorized?
      Feed.all
    else
      Feed.where("podcast_id IN (SELECT id FROM podcasts WHERE prx_account_uri IN (?))", token_auth_account_uris)
    end
  end

  # avoid joining podcasts here, as it breaks a bunch of other queries
  def token_auth_episodes
    if globally_authorized?
      Episode.all
    else
      Episode.where("podcast_id IN (SELECT id FROM podcasts WHERE prx_account_uri IN (?))", token_auth_account_uris)
    end
  end
end
