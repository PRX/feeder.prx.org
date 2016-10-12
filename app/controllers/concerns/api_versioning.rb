# encoding: utf-8

require 'active_support/concern'

# expects underlying model to have filename, class, and id attributes
module ApiVersioning

  extend ActiveSupport::Concern

  def api_version
    params[:api_version]
  end

  def check_api_version
    unless self.class.understood_api_versions.include?(api_version)
      render status: :not_acceptable, file: 'public/404.html'
      false
    end
  end

  module ClassMethods

    attr_accessor :understood_api_versions

    def api_versions(*versions)
      self.understood_api_versions = versions.map(&:to_s)
      before_filter :check_api_version
    end
  end
end
