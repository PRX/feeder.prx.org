module StreamRecordingsHelper
  def stream_record_days_options
    StreamRecording::ALL_DAYS.map do |day|
      [I18n.t("date.day_names")[day % 7], day]
    end
  end

  def stream_record_hours_options
    StreamRecording::ALL_HOURS.map do |hour|
      [Time.new(2000, 1, 1, hour, 0, 0).strftime("%l %p").strip, hour]
    end
  end
end
