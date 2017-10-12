# encoding: utf-8

class Api::AuthorizationsController < Api::BaseController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::AuthorizationRepresenter

  private

  def resource
    authorization
  end
end
