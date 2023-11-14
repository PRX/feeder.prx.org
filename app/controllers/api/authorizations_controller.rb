class Api::AuthorizationsController < Api::BaseController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::AuthorizationRepresenter

  private

  def resource
    authorization
  end

  def show_cache_path
    authorization.cache_key
  end
end
