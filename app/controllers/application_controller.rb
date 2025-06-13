class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include ClickhouseUtils

  protect_from_forgery with: :exception

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  default_form_builder FeederFormBuilder

  before_action :redirect_api_requests

  def nilify(p)
    p.transform_values { |v| v.present? ? v : nil }
  end

  protected

  # make sure json/hal requests to the root redirect to /api/v1
  def redirect_api_requests
    if request.path == "/" && (request.format.json? || request.format.hal?)
      redirect_to api_root_path
    end
  end

  def user_not_authorized(exception = nil)
    @policy = exception ? exception.policy.class.to_s.underscore : "n/a"
    @query = exception ? exception.query : "n/a"
    render "errors/forbidden", status: :forbidden
  end

  def skip_session
    request.session_options[:skip] = true
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
