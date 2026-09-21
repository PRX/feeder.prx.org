class AlternateMediaResource < MediaResource
  def original_ext
    ".m3u8"
  end

  def file_name
    super.sub(/\.[^.]*$/, "") + ".m3u8"
  end

  def copy_media(force = false)
    # todo transcode HLS
  end
end
