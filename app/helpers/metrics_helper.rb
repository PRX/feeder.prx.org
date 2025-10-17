module MetricsHelper
  def sum_rollups(rollups)
    rollups.sum(&:count)
  end

  def interval_options
    Rollups::HourlyDownload::INTERVALS.map { |i| [I18n.t(".helpers.label.metrics.interval.#{i.downcase}"), i] }
  end

  def main_card_options
    [
      ["downloads", "downloads"],
      ["episodes", "episodes"],
      ["uniques", "uniques"],
      ["dropdays", "dropdays"]
    ]
  end

  def date_range_options(episode = nil)
    if episode
      episode_date_presets(episode)
    else
      podcast_date_presets
    end
  end

  def podcast_date_presets
    metrics_date_presets(Rollups::HourlyDownload::PODCAST_DATE_PRESETS)
  end

  def episode_date_presets(episode)
    metrics_date_presets(Rollups::HourlyDownload::EPISODE_DATE_PRESETS, episode)
  end

  def metrics_date_presets(options, episode = nil)
    options.map do |opt|
      count, interval, type = opt.to_s.split("_")

      date_start = if type == "last"
        count.to_i.send(interval).ago.utc_date
      elsif type == "previous"
        (Date.utc_today - count.to_i.send(interval)).send(:"beginning_of_#{interval.singularize}")
      elsif count == "date"
        Date.utc_today.send(:"beginning_of_#{interval.singularize}")
      elsif episode
        episode.first_publish_utc_date
      else
        Date.utc_today - 1.day
      end

      date_end = if type == "drop"
        date_start + count.to_i.send(interval)
      elsif type == "previous"
        (date_start + (count.to_i - 1).send(interval)).send(:"end_of_#{interval.singularize}")
      else
        Date.utc_today
      end

      [I18n.t(".helpers.label.metrics.date_presets.#{opt}"), date_preset(date_start, date_end)]
    end
  end

  def guard_date_end(date_end)
    if date_end > Date.utc_today
      Date.utc_today
    else
      date_end
    end
  end

  def date_preset(date_start, date_end)
    [
      date_start,
      guard_date_end(date_end)
    ].to_json
  end

  def dropday_range_options
    Rollups::HourlyDownload::DROPDAY_OPTIONS.map { |opt| [I18n.t(".helpers.label.metrics.dropdays.#{opt}"), opt] }
  end

  def uniques_selection_options
    Rollups::DailyUnique::UNIQUE_OPTIONS.map { |opt| [I18n.t(".helpers.label.metrics.uniques.#{opt}"), opt] }
  end

  def agent_downloads_with_percent(rollups, totals)
    sum = if rollups.is_a?(Integer)
      rollups
    else
      sum_rollups(rollups)
    end
    total_downloads = if totals.is_a?(Integer)
      totals
    elsif totals.present?
      sum_rollups(totals)
    else
      0
    end
    percent = ((sum.to_f / total_downloads.to_f) * 100).truncate(1)

    "#{sum} (#{percent}%)"
  end
end
