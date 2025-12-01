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

  def stream_record_days_options(val)
    label = I18n.t("helpers.label.stream_recording.record_all_days")
    all = [label, "", {selected: val.blank?, data: {mandatory: true}}]
    opts = StreamRecording::ALL_DAYS.map { |d| [I18n.t("date.day_names")[d % 7], d] }
    options_for_select(opts.prepend(all), val)
  end

  def stream_record_hours_options(val)
    label = I18n.t("helpers.label.stream_recording.record_all_hours")
    all = [label, "", {selected: val.blank?, data: {mandatory: true}}]
    opts = StreamRecording::ALL_HOURS.map { |h| [Time.new(2000, 1, 1, h, 0, 0).strftime("%l %p").strip, h] }
    options_for_select(opts.prepend(all), val)
  end
end
