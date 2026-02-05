module StreamRecordingsHelper
  def stream_status_options
    StreamRecording.statuses.keys.map { |k| [I18n.t("helpers.label.stream_recording.statuses.#{k}"), k] }
  end

  def stream_create_as_options
    StreamRecording.create_as.keys.map { |k| [I18n.t("helpers.label.stream_recording.create_as_opts.#{k}"), k] }
  end

  def stream_expiration_options
    I18n.t("helpers.label.stream_recording.expirations").invert.to_a
  end

  def stream_record_days_data(stream)
    {
      value_was: stream.record_days_was.blank? ? [StreamRecording::ALL_PLACEHOLDER] : stream.record_days.map(&:to_s),
      slim_select_exclusive_value: [StreamRecording::ALL_PLACEHOLDER],
      slim_select_max_values_shown_value: 3
    }
  end

  def stream_record_hours_data(stream)
    {
      value_was: stream.record_hours_was.blank? ? [StreamRecording::ALL_PLACEHOLDER] : stream.record_hours.map(&:to_s),
      slim_select_exclusive_value: [StreamRecording::ALL_PLACEHOLDER],
      slim_select_max_values_shown_value: 5
    }
  end

  def stream_record_days_options(stream)
    label = I18n.t("helpers.label.stream_recording.record_all_days")
    all = [label, StreamRecording::ALL_PLACEHOLDER, {selected: stream.record_days.blank?, data: {mandatory: true}}]
    opts = StreamRecording::ALL_DAYS.map { |d| [I18n.t("date.day_names")[d], d] }
    options_for_select(opts.prepend(all), stream.record_days)
  end

  def stream_record_hours_options(stream)
    label = I18n.t("helpers.label.stream_recording.record_all_hours")
    all = [label, StreamRecording::ALL_PLACEHOLDER, {selected: stream.record_hours.blank?, data: {mandatory: true}}]
    opts = StreamRecording::ALL_HOURS.map { |h| [Time.new(2000, 1, 1, h, 0, 0).strftime("%l %p").strip, h] }
    options_for_select(opts.prepend(all), stream.record_hours)
  end

  def stream_date(resource)
    if resource.start_at
      tz = resource.stream_recording&.time_zone
      I18n.l(resource.start_at.in_time_zone(tz), format: :short)
    end
  end

  def stream_hour(resource)
    if resource.start_at && resource.end_at
      tz = resource.stream_recording&.time_zone
      start_at = I18n.l(resource.start_at.in_time_zone(tz), format: :time_12_hour)
      end_at = I18n.l(resource.end_at.in_time_zone(tz), format: :time_12_hour_zone)
      "#{start_at} - #{end_at}"
    end
  end
end
