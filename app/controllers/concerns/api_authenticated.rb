require "active_support/concern"

module ApiAuthenticated
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  def authenticate_user!
    user_not_authorized unless prx_auth_token
  end

  def cache_show?
    false
  end

  def cache_index?
    false
  end
end
