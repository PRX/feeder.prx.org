# encoding: utf-8
require 'hal_api/rails'

class Api::BaseController < ApplicationController
  include HalApi::Controller
  include Pundit
  include ApiVersioning

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def pundit_user
    prx_auth_token
  end

  def user_not_authorized
    message = { error: 'You are not authorized to perform this action' }
    render json: message, status: 401
  end

  protect_from_forgery with: :null_session

  allow_params :show, :zoom
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
