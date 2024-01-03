require "active_support/concern"

module ApiAuthenticated
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  def authenticated?
    api_admin_token? || prx_auth_token
  end

  def authenticate_user!
    user_not_authorized unless authenticated?
  end

  # don't bother calculating cache keys if user will be 401'd anyways
  def index_cache_path
    super if authenticated?
  end

  def show_cache_path
    super if authenticated?
  end
end
