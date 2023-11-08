class Api::AuthorizationsController < Api::BaseController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::AuthorizationRepresenter

  private

  def resource
    authorization
  end

  # this is the only auth#show endpoint not cached, since it's specific to a user
  def cache_show?
    false
  end
end
