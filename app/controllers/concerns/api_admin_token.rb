require "active_support/concern"

module ApiAdminToken
  extend ActiveSupport::Concern

  def api_admin_tokens
    ENV.fetch("API_ADMIN_TOKENS", "").split(",").compact
  end

  def api_admin_token?
    token = (request.headers["HTTP_AUTHORIZATION"] || "").split("Token ").last
    api_admin_tokens.include?(token)
  end

  def api_admin_token!
    user_not_authorized unless api_admin_token?
  end
end
