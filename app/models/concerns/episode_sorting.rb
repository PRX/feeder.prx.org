require "active_support/concern"

module EpisodeSorting
  extend ActiveSupport::Concern

  SORTS = {
    calendar: "",
    asc: "asc",
    desc: "desc",
    recent: "recent"
  }

  def self.key(value)
    SORTS.key(value) || "calendar"
  end

  included do
    scope :sort_by_alias, ->(sort) do
      if sort == "asc"
        dropdate_asc
      elsif sort == "desc"
        dropdate_desc
      elsif sort == "recent"
        order(updated_at: :desc)
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
