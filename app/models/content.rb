class Content < MediaResource

  def self.build_from_content(episode, content)
    new.tap do |c|
      c.episode = episode
      c.update_content_attributes(content)
    end
  end

  def update_with_content!(content)
    update_content_attributes(content)
    save!
    self
  end

  def update_content_attributes(content)
    %w(position medium expression channels duration height width lang).each do |at|
      try("#{at}=", content[at])
    end

    self.href = content['url']
    self.mime_type = content['type']
    self.file_size = content['file_size'].to_i
    self.bit_rate = content['bitrate'].to_i
    self.frame_rate = content['framerate'].to_i
    self.sample_rate = content['samplingrate'].to_f * 1000
    self.is_default = content['is_default']&.casecmp('true')&.zero?
    self
  end

  def replace_resources!
    episode.with_lock do
      # delete enclosures in the same episode created before this
      episode.all_contents.where('position = ? AND created_at < ? AND id != ?', position, created_at, id).destroy_all
    end
  end
end
