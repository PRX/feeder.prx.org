require "active_support/concern"

module ApiPublishedRange
  extend ActiveSupport::Concern

  included do
    class_eval do
      allow_params :index, [:after, :before]
    end
  end

  def filtered(resources)
    if published_after.present? && published_before.present?
      super.after(published_after).before(published_before)
    elsif published_after.present?
      super.after(published_after)
    elsif published_before.present?
      super.before(published_before)
    else
      super
    end
  end

  def published_after
    DateTime.parse(params[:after])
  rescue
    nil
  end

  def published_before
    DateTime.parse(params[:before])
  rescue
    nil
  end
end
