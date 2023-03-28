class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  default_form_builder FeederFormBuilder

  before_action :set_after_sign_in_path, :authenticate!
  skip_before_action :set_after_sign_in_path, :authenticate!, only: [:logout, :refresh]

  def logout
    sign_out_user
    redirect_to "//#{PrxAuth::Rails.configuration.id_host}/session/sign_out", allow_other_host: true
  end

  def refresh
    sign_out_user
    redirect_to PrxAuth::Rails::Engine.routes.url_helpers.new_sessions_path
  end

  protected

  def user_not_authorized(exception)
    @policy = exception.policy.class.to_s.underscore
    @query = exception.query
    render "errors/forbidden", status: :forbidden
  end

  def after_sign_in_path_for(_resource)
    main_app.fake_index_path
  end

  # TODO: some way to trigger full reload on session expiration
  # https://github.com/hotwired/turbo/issues/138
  def prx_auth_needs_refresh?(jwt_ttl)
    if request.headers["Turbo-Frame"]
      false
    else
      super(jwt_ttl)
    end
  end

  def skip_session
    request.session_options[:skip] = true
  end
end
