module PodcastMetricsHelper
  def parse_agent_data(agents)
    agents.map do |a|
      {
        x: a.label,
        y: a.count
      }
    end
  end

  def sum_rollups(rollups)
    rollups.map { |r| r[:count] }.reduce(:+)
  end

  def interval_options
    Rollups::HourlyDownload::INTERVALS.map { |i| [I18n.t(".helpers.label.metrics.interval.#{i.downcase}"), i] }
  end

  def date_range_options
    Rollups::HourlyDownload::PODCAST_DATE_PRESETS.map do |opt|
      count, interval = opt.to_s.split("_")
      date_end = Date.utc_today
      date_start = if count.to_i > 0
        count.to_i.send(interval).ago.utc.to_date
      else
        Date.utc_today.send(:"beginning_of_#{interval}")
      end

      [I18n.t(".helpers.label.metrics.date_presets.#{opt}"), [date_start, date_end].to_json]
    end
  end

  def dropday_range_options
    Rollups::HourlyDownload::DROPDAY_OPTIONS.map { |opt| [I18n.t(".helpers.label.metrics.dropdays.#{opt}"), opt] }
  end

  def uniques_selection_options
    Rollups::DailyUnique::UNIQUE_OPTIONS.map { |opt| [I18n.t(".helpers.label.metrics.uniques.#{opt}"), opt] }
  end
end
