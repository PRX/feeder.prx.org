class AudioFile
  def initialize(enclosure_info)
    @href = enclosure_info[:url]
    @type = enclosure_info[:type]
    @size = enclosure_info[:size]
    @duration = enclosure_info[:duration]
  end

  def as_json(*args)
    {
      href: @href,
      type: @type,
      size: @size,
      duration: @duration
    }
  end
end
