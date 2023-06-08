require "active_support/concern"

module FeedAudioFormat
  extend ActiveSupport::Concern

  def audio_type
    audio_format[:f] if audio_format.present? && audio_format[:f].present?
  end

  def audio_type=(format)
    audio_format[:f] = format
  end

  def audio_bitrate
    audio_format[:b] if audio_format.present? &&  audio_format[:b].present?
  end

  def audio_bitrate=(bitrate)
    audio_format[:b] = bitrate if audio_format[:f] == "mp3"
  end

  def audio_bitdepth
    audio_format[:b] if audio_format.present? && audio_format[:b].present?
  end

  def audio_bitdepth=(bitdepth)
    audio_format[:b] = bitdepth if ["wav", "flac"].include?(audio_format[:f])
  end

  def audio_channel
    audio_format[:c] if audio_format.present? && audio_format[:c].present?
  end

  def audio_channel=(channel)
    audio_format[:c] = channel
  end

  def audio_sample
    audio_format[:s] if audio_format.present? && audio_format[:s].present?
  end

  def audio_sample=(sample)
    audio_format[:s] = sample
  end
end
