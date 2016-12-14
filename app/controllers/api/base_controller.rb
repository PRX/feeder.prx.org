# encoding: utf-8
require 'hal_api/rails'
require 'hal_api/errors'

class Api::BaseController < ApplicationController
  include HalApi::Controller
  include Pundit
  include ApiVersioning

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  rescue_from HalApi::Errors::NotFound do |error|
    if self.class.resource_class.try(:paranoid?)
      gone = resources_base.with_deleted.send(self.class.find_method, params[:id]).try(:deleted?)
      error = ResourceGone.new if gone
    end
    respond_with_error(error)
  end

  def user_not_authorized
    respond_with_error(NotAuthorized.new)
  end

  def pundit_user
    prx_auth_token
  end

  protect_from_forgery with: :null_session

  allow_params :show, [:api_version, :format, :zoom]
  allow_params :index, [:page, :per, :zoom]

  cache_api_action :show, if: :cache_show?
  cache_api_action :index, if: :cache_index?

  caches_action :entrypoint, cache_path: ->(_c) { { _c: Api.version(api_version).cache_key } }

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
    super(message || 'Resource gone', 410)
  end
end

class NotAuthorized < HalApi::Errors::ApiError
  def initialize(message = nil)
    super(message || 'You are not authorized to perform this action', 401)
  end
end
