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
        content = "episode_filter_contents"
        external = "episode_filter_external_media_resources"
        complete = MediaResource.statuses[:complete]
        override = "COALESCE(episodes.medium = #{Episode.mediums[:override]}, FALSE) OR COALESCE(BTRIM(episodes.enclosure_override_url), '') != ''"

        content_count = "COUNT(DISTINCT #{content}.id)"
        complete_content_count = "#{content_count} FILTER (WHERE #{content}.status = #{complete})"
        complete_external_count = "COUNT(DISTINCT #{external}.id) FILTER (WHERE #{external}.status = #{complete})"

        media_not_ready = [
          "#{content_count} = 0",
          "(episodes.segment_count IS NULL AND #{content_count} < MAX(#{content}.position))",
          "#{content_count} < COALESCE(episodes.segment_count, 0)",
          "#{complete_content_count} != #{content_count}"
        ].join(" OR ")

        joins(<<~SQL.squish)
          LEFT OUTER JOIN media_resources #{content}
            ON #{content}.episode_id = episodes.id
            AND #{content}.type = 'Content'
            AND #{content}.deleted_at IS NULL
          LEFT OUTER JOIN LATERAL (
            SELECT *
            FROM media_resources
            WHERE media_resources.episode_id = episodes.id
              AND media_resources.type = 'ExternalMediaResource'
              AND media_resources.deleted_at IS NULL
            ORDER BY media_resources.created_at DESC
            LIMIT 1
          ) #{external} ON TRUE
        SQL
          .group(:id)
          .having(<<~SQL.squish)
            ((#{override}) AND #{complete_external_count} = 0)
            OR
            (NOT (#{override}) AND (#{media_not_ready}))
          SQL
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
