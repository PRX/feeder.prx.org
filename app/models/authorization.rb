# encoding: utf-8

class Authorization
  include HalApi::RepresentedModel

  attr_accessor :token

  def initialize(token)
    @token = token
  end

  def user_id
    token.user_id
  end

  def to_model
    self
  end

  def persisted?
    false
  end

  def cache_key
    token_key = OpenSSL::Digest::MD5.hexdigest(token.attributes.flatten.join)
    ActiveSupport::Cache.expand_cache_key(['PRX::Authorization', token_key])
  end

  def token_auth_account_ids
    token.authorized_resources.try(:keys) || []
  end

  def token_auth_account_uris
    token_auth_account_ids.map { |id| "/api/v1/accounts/#{id}" }
  end

  def token_auth_podcasts
    Podcast.where(prx_account_uri: token_auth_account_uris)
  end

  # avoid joining podcasts here, as it breaks a bunch of other queries
  def token_auth_episodes
    Episode.where(podcast_id: token_auth_podcasts.pluck(:id))
  end
end
