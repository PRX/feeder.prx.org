module MetricsHelper
  def sum_rollups(rollups)
    rollups.sum(&:count)
  end

  def interval_options
    Rollups::HourlyDownload::INTERVALS.map { |i| [I18n.t(".helpers.label.metrics.interval.#{i.downcase}"), i] }
  end

  def main_card_options
    %i[downloads episodes uniques dropdays]
  end

  def agents_card_options
    %i[agent_apps agent_types agent_os]
  end

  def podcast_date_preset_options
    Rollups::HourlyDownload::PODCAST_DATE_PRESETS.map do |preset|
      [label_for_preset(preset), preset.to_s]
    end
  end

  def episode_date_preset_options
    Rollups::HourlyDownload::EPISODE_DATE_PRESETS.map do |preset|
      [I18n.t(".helpers.label.metrics.date_presets.#{preset}"), preset.to_s]
    end
  end

  def label_for_preset(preset)
    I18n.t(".helpers.label.metrics.date_presets.#{preset}")
  end

  def dates_from_preset(preset, episode = nil)
    type, count, interval = preset.to_s.split("_")

    date_start = if date_start_from_preset(type, count, interval)
      date_start_from_preset(type, count, interval)
    elsif episode
      episode.first_publish_utc_date
    else
      Date.utc_today - 1.day
    end

    date_end = date_end_from_preset(date_start, type, count, interval)

    [date_start, guard_date_end(date_end)]
  end

  def active_preset(preset, option)
    if preset == option[1]
      "active"
    end
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

  private

  def date_start_from_preset(type, count, interval)
    if type == "last"
      count.to_i.send(interval).ago.utc_date
    elsif type == "previous"
      (Date.utc_today - count.to_i.send(interval)).send(:"beginning_of_#{interval.singularize}")
    elsif type == "todate"
      Date.utc_today.send(:"beginning_of_#{interval.singularize}")
    end
  end

  def date_end_from_preset(date_start, type, count, interval)
    if type == "drop"
      date_start + count.to_i.send(interval)
    elsif type == "previous"
      (date_start + (count.to_i - 1).send(interval)).send(:"end_of_#{interval.singularize}")
    else
      Date.utc_today
    end
  end

  def guard_date_end(date_end)
    if date_end > Date.utc_today
      Date.utc_today
    else
      date_end
    end
  end
end
