require "active_support/concern"

module ApiUpdatedSince
  extend ActiveSupport::Concern

  included do
    class_eval do
      allow_params :index, [:since]
    end
  end

  def filtered(resources)
    if updated_since_with_deleted?
      super.with_deleted.where("updated_at >= ?", updated_since).reorder(updated_at: :asc, id: :asc)
    elsif updated_since?
      super.where("updated_at >= ?", updated_since).reorder(updated_at: :asc, id: :asc)
    else
      super
    end
  end

  def updated_since_with_deleted?
    updated_since? && authorization&.globally_authorized?
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
