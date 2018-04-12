# encoding: utf-8

require 'active_support/concern'

module ApiUpdatedSince
  extend ActiveSupport::Concern

  included do
    class_eval do
      allow_params :index, [:since]
    end
  end

  def resources_base
    if updated_since?
      super.where('updated_at >= ?', updated_since).order('updated_at asc')
    else
      super
    end
  end

  def updated_since?
    updated_since.present?
  end

  def updated_since
    DateTime.parse(params[:since])
  rescue
    nil
  end
end
