require "active_support/concern"

module FeedAudioFormat
  extend ActiveSupport::Concern

  def audio_type
    audio_format.try(:[], :f)
  end

  def audio_type=(type)
    self.audio_format ||= {}
    type.present? ? audio_format[:f] = type : self.audio_format = nil
  end

  def audio_bitrate
    audio_format.try(:[], :b) if audio_format.try(:[], :f) == "mp3"
  end

  def audio_bitrate=(bitrate)
    return unless audio_format.present?
    return unless audio_format.try(:[], :f) == "mp3"

    audio_format[:b] = bitrate.to_i
  end

  def audio_bitdepth
    audio_format.try(:[], :b) if %w[wav flac m4a].include?(audio_format.try(:[], :f))
  end

  def audio_bitdepth=(bitdepth)
    return unless audio_format.present?
    return unless %w[wav flac m4a].include?(audio_format.try(:[], :f))

    audio_format[:b] = bitdepth.to_i
  end

  def audio_channel
    audio_format.try(:[], :c)
  end

  def audio_channel=(channel)
    return unless audio_format.present?

    audio_format[:c] = channel.to_i
  end

  def audio_sample
    audio_format.try(:[], :s)
  end

  def audio_sample=(sample)
    return unless audio_format.present?

    audio_format[:s] = sample.to_i
  end
end
