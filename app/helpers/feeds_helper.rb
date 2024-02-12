module FeedsHelper
  def episode_offset_options
    I18n.t("feeds.helper.episode_offset_options").invert.to_a
  end

  def audio_format_options
    AudioFormatValidator::FORMATS.map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_format_options]), value]
    end
  end

  def audio_bitrate_options
    AudioFormatValidator::BIT_RATES.map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_bitrate_options]), value]
    end
  end

  def audio_bitdepth_options
    AudioFormatValidator::BIT_DEPTHS.map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_bitdepth_options]), value]
    end
  end

  def audio_channel_options
    AudioFormatValidator::CHANNELS.map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_channel_options]), value]
    end
  end

  def audio_sample_options
    AudioFormatValidator::SAMPLE_RATES.map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_sample_options]), value]
    end
  end

  def feed_tokens_destroy_params(form)
    params = {}
    params["#{form.object_name}[id]"] = form.object.id
    params["#{form.object_name}[_destroy]"] = "1"

    params
  end

  def display_bitrate(feed)
    (feed.try(:audio_format).try(:[], :f) == "mp3") ? "" : "d-none"
  end

  def display_bitdepth(feed)
    %w[wav flac].include?(feed.try(:audio_format).try(:[], :f)) ? "" : "d-none"
  end

  def display_audio_format(feed)
    feed.audio_format.blank? ? "d-none" : ""
  end

  def feed_destroy_image_path(feed, form)
    if feed.new_record?
      new_podcast_feed_path feed.podcast, uploads_destroy_params(form)
    else
      podcast_feed_path feed.podcast, feed, uploads_destroy_params(form)
    end
  end

  def feed_retry_image_path(feed, form)
    if feed.new_record?
      new_podcast_feed_path feed.podcast, uploads_retry_params(form)
    else
      podcast_feed_path feed.podcast, feed, uploads_retry_params(form)
    end
  end
end
