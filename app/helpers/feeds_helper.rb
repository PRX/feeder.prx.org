module FeedsHelper
  def episode_offset_options
    values = [300, 900, 3600, 21600, 43200, 86400]

    I18n.t(values, scope: [:feeds, :helper, :episode_offset_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_format_options
    values = ["mp3", "flac", "wav"]

    I18n.t(values, scope: [:feeds, :helper, :audio_format_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_bitrate_options
    values = [96, 112, 128, 160, 192, 224, 256, 320]

    I18n.t(values, scope: [:feeds, :helper, :audio_bitrate_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_bitdepth_options
    values = [16, 24, 32]

    I18n.t(values, scope: [:feeds, :helper, :audio_bitdepth_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_channel_options
    values = [1, 2]

    I18n.t(values, scope: [:feeds, :helper, :audio_channel_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_sample_options
    values = [8000, 11025, 12000, 16000, 22050, 24000, 44100, 48000]

    I18n.t(values, scope: [:feeds, :helper, :audio_sample_options]).map.with_index { |label, i| [label, values[i]] }
  end
end
