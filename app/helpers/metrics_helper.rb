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

  def podcast_main_card_options
    %i[downloads episodes uniques dropdays]
  end

  def interval_options
    Rollups::HourlyDownload::INTERVALS.map { |i| [I18n.t(".helpers.label.metrics.interval.#{i.downcase}"), i] }
  end

  def date_preset_options(episode = nil)
    if episode
      episode_date_preset_options
    else
      podcast_date_preset_options
    end
  end

  def podcast_date_preset_options
    Rollups::HourlyDownload::PODCAST_DATE_PRESETS.map do |preset|
      [label_for_date_preset(preset), preset.to_s]
    end
  end

  def episode_date_preset_options
    Rollups::HourlyDownload::EPISODE_DATE_PRESETS.map do |preset|
      [label_for_date_preset(preset), preset.to_s]
    end
  end

  def dates_from_preset(preset, episode = nil)
    date_start = if date_start_from_preset(preset)
      date_start_from_preset(preset)
    elsif episode
      episode.first_publish_utc_date
    else
      Date.utc_today - 1.day
    end

    date_end = date_end_from_preset(preset, date_start)

    [date_start, guard_date_end(date_end)]
  end

  def date_start_from_preset(preset)
    type, count, interval = preset.to_s.split("_")

    if type == "last"
      count.to_i.send(interval).ago.utc_date
    elsif type == "previous"
      (Date.utc_today - count.to_i.send(interval)).send(:"beginning_of_#{interval.singularize}")
    elsif type == "todate"
      Date.utc_today.send(:"beginning_of_#{interval.singularize}")
    end
  end

  def date_end_from_preset(preset, date_start)
    type, count, interval = preset.to_s.split("_")

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

  def active_preset(option, selected)
    if option == selected
      "active"
    end
  end

  def label_for_date_preset(preset)
    I18n.t(".helpers.label.metrics.date_presets.#{preset}")
  end

  def dropday_range_options
    Rollups::HourlyDownload::DROPDAY_OPTIONS.map { |opt| [I18n.t(".helpers.label.metrics.dropdays.#{opt}"), opt] }
  end

  def uniques_selection_options
    Rollups::DailyUnique::UNIQUE_OPTIONS.map { |opt| [I18n.t(".helpers.label.metrics.uniques.#{opt}"), opt] }
  end
end
