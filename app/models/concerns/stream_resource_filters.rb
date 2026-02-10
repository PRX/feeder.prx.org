require "active_support/concern"

module StreamResourceFilters
  extend ActiveSupport::Concern

  FILTERS = {
    all: "",
    recording: "recording",
    complete: "complete",
    short: "short"
  }

  SORTS = {
    desc: "",
    asc: "asc"
  }

  def self.filter_key(value)
    FILTERS.key(value) || "all"
  end

  def self.sort_key(value)
    SORTS.key(value) || "desc"
  end

  included do
    scope :filter_by_alias, ->(filter) do
      if filter == "recording"
        where(status: %w[processing recording])
      elsif filter == "complete"
        where(status: %w[complete invalid short error])
      elsif filter == "short"
        where(status: %w[complete short]).short
      end
    end

    scope :filter_by_date, ->(stream_recording, date) do
      if date.present?
        tz = stream_recording&.time_zone || "UTC"
        start_date = date.to_date.in_time_zone(tz).utc
        end_date = start_date + 1.day
        where(start_at: start_date...end_date)
      end
    end

    scope :sort_by_alias, ->(sort) do
      if sort == "asc"
        order(start_at: :asc)
      else
        order(start_at: :desc)
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
