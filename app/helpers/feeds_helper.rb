module FeedsHelper
  def episode_offset_options
    values = [300, 900, 3600, 21600, 43200, 86400]

    I18n.t([:min_5, :min_15, :hr_1, :hr_6, :hr_12, :hr_24], scope: [:feeds, :helper, :episode_offset_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_format_options
    values = ["mp3", "flac", "wav"]

    I18n.t([:mp3, :flac, :wav], scope: [:feeds, :helper, :audio_format_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_bitrate_options
    values = [96, 112, 128, 160, 192, 224, 256, 320]

    I18n.t([:kb_96, :kb_112, :kb_128, :kb_160, :kb_192, :kb_224, :kb_256, :kb_320], scope: [:feeds, :helper, :audio_bitrate_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_bitdepth_options
    values = [16, 24, 32]

    I18n.t([:b_16, :b_24, :b_32], scope: [:feeds, :helper, :audio_bitdepth_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_channel_options
    values = [1, 2]

    I18n.t([:mono, :stereo], scope: [:feeds, :helper, :audio_channel_options]).map.with_index { |label, i| [label, values[i]] }
  end

  def audio_sample_options
    values = [8000, 11025, 12000, 16000, 22050, 24000, 44100, 48000]

    I18n.t([:khz_8, :khz_11, :khz_12, :khz_16, :khz_22, :khz_24, :khz_44, :khz_48], scope: [:feeds, :helper, :audio_sample_options]).map.with_index { |label, i| [label, values[i]] }
  end
end
