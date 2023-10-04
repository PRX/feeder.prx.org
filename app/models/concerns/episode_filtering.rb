require "active_support/concern"

module EpisodeFiltering
  extend ActiveSupport::Concern

  FILTERS = {
    all: "",
    incomplete: "incomplete"
  }

  def self.key(value)
    FILTERS.key(value) || "all"
  end

  included do
    scope :filter_by_alias, ->(filter) do
      if filter == "incomplete"
        incomplete = "COUNT(media_resources) != COUNT(media_resources) FILTER (WHERE status = #{MediaResource.statuses[:complete]})"
        missing = "segment_count IS NOT NULL AND segment_count != COUNT(media_resources)"
        left_joins(:contents).group(:id).having("#{incomplete} OR #{missing}")
      end
    end
  end
end
