class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  default_form_builder FeederFormBuilder

  before_action :redirect_api_requests, :set_after_sign_in_path, :authenticate!
  skip_before_action :set_after_sign_in_path, :authenticate!, only: [:logout, :refresh]

  def logout
    sign_out_user
    redirect_to "//#{PrxAuth::Rails.configuration.id_host}/session/sign_out", allow_other_host: true
  end

  def refresh
    sign_out_user
    redirect_to PrxAuth::Rails::Engine.routes.url_helpers.new_sessions_path
  end

  def nilify(p)
    p.transform_values { |v| v.present? ? v : nil }
  end

  # TEMPORARY: remove CMS authorized accounts from using Feeder UI-only
  # NOTE: the API uses prx_auth_token directly, not current_user
  def current_user
    cms_accounts = prx_auth_token&.resources(:cms, :read_private)
    prx_auth_token&.except(*cms_accounts)
  end

  protected

  # make sure json/hal requests to the root redirect to /api/v1
  def redirect_api_requests
    if request.path == "/" && (request.format.json? || request.format.hal?)
      redirect_to api_root_path
    end
  end

  # check for > 0 feeder authorized accounts
  def authenticate!
    if super == true
      unless current_user.globally_authorized?(:read_private) || current_user.authorized_account_ids(:read_private).any?
        render "errors/no_access", layout: "plain"
      end
    end
  end

  def user_not_authorized(exception = nil)
    @policy = exception ? exception.policy.class.to_s.underscore : "n/a"
    @query = exception ? exception.query : "n/a"
    render "errors/forbidden", status: :forbidden
  end

  def after_sign_in_path_for(_resource)
    main_app.root_path
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

  # TODO: hacky, but this method is private in turbo-rails
  def turbo_frame_request?
    request.headers["Turbo-Frame"].present?
  end

  # include i18n (en.yml etc) in view fragment cache keys
  def view_cache_dependencies
    super.tap do |deps|
      if request.format.html?
        @@i18n_version ||= Digest::MD5.digest(I18n.backend.translations.to_s)
        deps << I18n.locale.to_s << @@i18n_version
      end
    end
  end
end
