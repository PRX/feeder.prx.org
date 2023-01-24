class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery with: :exception

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def user_not_authorized(exception)
    @policy = exception.policy.class.to_s.underscore
    @query = exception.query
    render 'errors/forbidden', status: :forbidden
  end
end
