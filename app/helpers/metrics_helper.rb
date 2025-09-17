module MetricsHelper
  def parse_agent_data(agents)
    agents.map do |a|
      {
        x: a.label,
        y: a.count
      }
    end
  end

  def sum_rollups(rollups)
    rollups.sum(&:count)
  end

  def interval_options
    Rollups::HourlyDownload::INTERVALS.map { |i| [I18n.t(".helpers.label.metrics.interval.#{i.downcase}"), i] }
  end

  def date_range_options(episode = nil)
    if episode
      episode_date_presets(episode)
    else
      podcast_date_presets
    end
  end

  def podcast_date_presets
    Rollups::HourlyDownload::PODCAST_DATE_PRESETS.map do |opt|
      count, interval = opt.to_s.split("_")
      date_end = Date.utc_today
      date_start = if count.to_i > 0
        count.to_i.send(interval).ago.utc_date
      else
        Date.utc_today.send(:"beginning_of_#{interval}")
      end

      [I18n.t(".helpers.label.metrics.date_presets.#{opt}"), date_preset(date_start, date_end)]
    end
  end

  def episode_date_presets(episode)
    Rollups::HourlyDownload::EPISODE_DATE_PRESETS.map do |opt|
      count, interval, type = opt.to_s.split("_")

      date_start = if type == "last"
        count.to_i.send(interval).ago.utc_date
      elsif count == "date"
        Date.utc_today.send(:"beginning_of_#{interval}")
      else
        episode.utc_publish_date
      end

      date_end = if type == "drop"
        date_start + count.to_i.send(interval)
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
end
