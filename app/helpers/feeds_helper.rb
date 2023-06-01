module FeedsHelper
  def episode_offset_options
    [300, 900, 3600, 21600, 43200, 86400].map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :episode_offset_options]), value]
    end
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

  def display_auth_tokens(feed)
    feed.private? ? "" : "d-none"
  end
end
