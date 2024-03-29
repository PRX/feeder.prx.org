require "hal_api/rails"
require "hal_api/errors"

class Api::BaseController < ApplicationController
  include HalApi::Controller
  include ApiAdminToken

  # these API endpoints use PRX JWTs, not session based auth
  skip_before_action :verify_authenticity_token

  # default to public API (unless including ApiAuthenticated)
  skip_before_action :authenticate!

  before_action :skip_session

  def self.responder
    Api::ApiResponder
  end

  include ApiVersioning

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def user_not_authorized(exception = nil)
    message = {status: 401, message: "You are not authorized to perform this action"}
    if exception && Rails.configuration.try(:consider_all_requests_local)
      message[:backtrace] = exception.backtrace
    end
    render json: message, status: 401
  end

  def pundit_user
    prx_auth_token
  end

  def authorization
    if prx_auth_token
      Authorization.new(prx_auth_token)
    elsif api_admin_token?
      Authorization.new(nil, true)
    end
  end

  allow_params :show, [:api_version, :format, :zoom]
  allow_params :index, [:page, :per, :zoom]

  cache_api_action :show, if: :cache_show?
  cache_api_action :index, if: :cache_index?

  caches_action :entrypoint, cache_path: ->(_c) { {_c: Api.version(api_version).cache_key} }

  def entrypoint
    respond_with Api.version(api_version)
  end

  def cache_show?
    true
  end

  def cache_index?
    true
  end

  def options
    head :no_content
  end
end

class ResourceGone < HalApi::Errors::ApiError
  def initialize(message = nil)
    super(message || "Resource gone", 410)
  end
end

class NotAuthorized < HalApi::Errors::ApiError
  def initialize(message = nil)
    super(message || "You are not authorized to perform this action", 401)
  end
end
