require "active_support/concern"

module PodcastFilters
  extend ActiveSupport::Concern

  SORTS = {
    asc: "asc",
    desc: "desc",
    recent: "",
    episodes: "episodes"
  }

  def self.sort_key(value)
    SORTS.key(value) || "recent"
  end

  included do
    scope :sort_by_alias, ->(sort) do
      if sort == "asc"
        order(title: :asc)
      elsif sort == "desc"
        order(title: :desc)
      elsif sort == "episodes"
        left_joins(:episodes).group(:id).order("COUNT(episodes.id) DESC")
      else
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
