require "active_support/concern"

module EpisodeImportFilters
  extend ActiveSupport::Concern

  FILTERS = {
    all: "",
    done: "done",
    undone: "undone",
    errors: "errors"
  }

  def self.filter_key(value)
    FILTERS.key(value) || "all"
  end

  included do
    scope :filter_by_alias, ->(filter) do
      if filter == "done"
        done
      elsif filter == "undone"
        undone
      elsif filter == "errors"
        errors
      end
    end

    scope :paginate, ->(page, per) do
      if per == "all"
        page(1).per(10000)
      else
        page(page).per(per)
      end
    end
  end
end
