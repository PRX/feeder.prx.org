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
    token_key = OpenSSL::Digest::MD5.hexdigest([token.scopes, token.resources].map(&:to_s).join(''))
    ActiveSupport::Cache.expand_cache_key(['PRX::Authorization', token_key])
  end

  def token_auth_account_ids
    token.resources
  end

  def token_auth_account_uris
    token_auth_account_ids.map { |id| "/api/v1/accounts/#{id}" }
  end

  def token_auth_podcasts
    if token.globally_authorized?('read-private')
      Podcast.all
    else
      Podcast.where(prx_account_uri: token_auth_account_uris)
    end
  end

  # avoid joining podcasts here, as it breaks a bunch of other queries
  def token_auth_episodes
    if token.globally_authorized?('read-private')
      Episode.all
    else
      Episode.where(podcast_id: token_auth_podcasts.pluck(:id))
    end
  end
end
