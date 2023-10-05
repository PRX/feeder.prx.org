require "active_support/concern"

module EpisodeFilters
  extend ActiveSupport::Concern

  FILTERS = {
    all: "",
    incomplete: "incomplete",
    published: "published"
  }

  SORTS = {
    calendar: "",
    recent: "recent",
    asc: "asc"
  }

  def self.filter_key(value)
    FILTERS.key(value) || "all"
  end

  def self.sort_key(value)
    SORTS.key(value) || "calendar"
  end

  included do
    scope :filter_by_alias, ->(filter) do
      if filter == "incomplete"
        incomplete = "COUNT(media_resources) != COUNT(media_resources) FILTER (WHERE status = #{MediaResource.statuses[:complete]})"
        missing = "segment_count IS NOT NULL AND segment_count != COUNT(media_resources)"
        left_joins(:contents).group(:id).having("#{incomplete} OR #{missing}")
      elsif filter == "published"
        published
      end
    end

    scope :sort_by_alias, ->(sort) do
      if sort == "asc"
        dropdate_asc
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
