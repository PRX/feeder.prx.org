module FeedsHelper
  def episode_offset_options
    [
      ['5 minutes', 300],
      ['15 minutes', 900],
      ['1 hour', 3600],
      ['6 hours', 21600],
      ['12 hours', 43200],
      ['24 hours', 86400]
    ]
  end

  def audio_format_options
    [
      ["MP3", "mp3"],
      ["FLAC", "flac"],
      ["WAV", "wav"]
    ]
  end

  def audio_bitrate_options
    [
      ['96 kbps', 96],
      ['112 kbps', 112],
      ['128 kbps', 128],
      ['160 kbps', 160],
      ['192 kbps', 192],
      ['224 kbps', 224],
      ['256 kbps', 256],
      ['320 kbps', 320]
    ]
  end

  def audio_bitdepth_options
    [
      ["16 bit", 16],
      ["24 bit", 24],
      ["32 bit", 32]
    ]
  end

  def audio_channel_options
    [
      ["Mono", 1],
      ["Stereo", 2]
    ]
  end

  def audio_sample_options
    [
      ['8 kHz', 8000],
      ['11.025 kHz', 11025],
      ['12 kHz', 12000],
      ['16 kHz', 16000],
      ['22.05 kHz', 22050],
      ['24 kHz', 24000],
      ['44.1 kHz', 44100],
      ['48 kHz', 48000]
    ]
  end
end
