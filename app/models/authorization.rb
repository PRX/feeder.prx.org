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
end
