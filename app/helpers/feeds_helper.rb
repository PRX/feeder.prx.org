module FeedsHelper
  def episode_offset_options
    [300, 900, 3600, 21600, 43200, 86400].map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :episode_offset_options]), value]
    end
  end

  def audio_format_options
    ["mp3", "flac", "wav"].map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_format_options]), value]
    end
  end

  def audio_bitrate_options
    [96, 112, 128, 160, 192, 224, 256, 320].map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_bitrate_options]), value]
    end
  end

  def audio_bitdepth_options
    [16, 24, 32].map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_bitdepth_options]), value]
    end
  end

  def audio_channel_options
    [1, 2].map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_channel_options]), value]
    end
  end

  def audio_sample_options
    [8000, 11025, 12000, 16000, 22050, 24000, 44100, 48000].map do |value|
      [I18n.t(value, scope: [:feeds, :helper, :audio_sample_options]), value]
    end
  end
end
