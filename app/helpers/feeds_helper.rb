module FeedsHelper
  def audio_format_options
    ["MP3", "FLAC", "WAV"]
  end

  def audio_bitrate_options
    ["96 kbps", "112 kbps", "128 kbps", "160 kbps", "192 kbps", "224 kbps"]
  end

  def audio_bitdepth_options
    ["16 bit", "24 bit", "32 bit"]
  end

  def audio_channel_options
    ["Mono", "Stereo"]
  end

  def audio_sample_options
    ["12 kHz", "16 kHz", "22.05 kHz", "24 kHz", "44.1 kHz", "48kHz"]
  end
end
