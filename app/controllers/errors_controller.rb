class ErrorsController < ActionController::Base
  include PrxAuth::Rails::Controller

  layout false
  skip_forgery_protection
  skip_before_action :authenticate!

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found
  end
end
