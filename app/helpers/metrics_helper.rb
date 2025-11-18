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

  def date_preset_options(episode = nil)
    if episode
      episode_date_preset_options
    else
      podcast_date_preset_options
    end
  end

  def podcast_date_preset_options
    Rollups::HourlyDownload::PODCAST_DATE_PRESETS.map do |preset|
      [label_for_date_preset_option(preset), preset.to_s]
    end
  end

  def episode_date_preset_options
    Rollups::HourlyDownload::EPISODE_DATE_PRESETS.map do |preset|
      [label_for_date_preset_option(preset), preset.to_s]
    end
  end

  def active_preset(option, selected)
    if option == selected
      "active"
    end
  end

  def label_for_date_preset_field(preset, date_start, date_end)
    preset_label = label_for_date_preset_option(preset)
    date_start_label = date_start.strftime("%b %d, %Y")
    date_end_label = date_end.strftime("%b %d, %Y")

    "#{preset_label}: #{date_start_label} - #{date_end_label}"
  end

  def label_for_date_preset_option(preset)
    I18n.t(".helpers.label.metrics.date_presets.#{preset}")
  end

  def dropday_range_options
    Rollups::HourlyDownload::DROPDAY_OPTIONS.map { |opt| [I18n.t(".helpers.label.metrics.dropdays.#{opt}"), opt] }
  end

  def uniques_selection_options
    Rollups::DailyUnique::UNIQUE_OPTIONS.map { |opt| [I18n.t(".helpers.label.metrics.uniques.#{opt}"), opt] }
  end
end
