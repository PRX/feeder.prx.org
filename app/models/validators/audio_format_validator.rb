class AudioFormatValidator < ActiveModel::EachValidator
  FORMATS = %w[mp3 wav flac].freeze
  BIT_RATES = [96, 112, 128, 160, 192, 224, 256, 320].freeze
  BIT_DEPTHS = [16, 24, 32].freeze
  CHANNELS = [1, 2].freeze
  SAMPLE_RATES = [8000, 11025, 12000, 16000, 22050, 24000, 44100, 48000]

  def validate_each(record, attribute, value)
    return if value.nil?

    # dovetail style: format, bitrate/bitdepth, channels, sample
    unless value.is_a?(Hash) && value.keys.sort == %w[b c f s]
      return record.errors.add attribute, "has an invalid audio format"
    end

    # https://github.com/PRX/dovetail-cdn-arranger#inputs
    unless %w[mp3 wav flac].include?(value["f"])
      return record.errors.add attribute, "unknown audio format: #{value["f"]}"
    end

    # bit rate/depth
    if value["f"] == "mp3"
      unless BIT_RATES.include?(value["b"])
        return record.errors.add attribute, "invalid bit rate: #{value["b"]}"
      end
    else
      unless BIT_DEPTHS.include?(value["b"])
        return record.errors.add attribute, "invalid bit depth: #{value["b"]}"
      end
    end

    # channels (mono or stereo)
    unless CHANNELS.include?(value["c"])
      return record.errors.add attribute, "invalid channels: #{value["c"]}"
    end

    # sample rate
    unless SAMPLE_RATES.include?(value["s"])
      record.errors.add attribute, "invalid sample rate: #{value["s"]}"
    end
  end
end
