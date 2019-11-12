class Enclosure < MediaResource
  def self.build_from_enclosure(episode, enclosure)
    new.tap do |e|
      e.episode = episode
      e.update_attributes_with_enclosure(enclosure)
    end
  end

  def update_with_enclosure!(enclosure)
    update_attributes_with_enclosure(enclosure)
    save!
    self
  end

  def update_attributes_with_enclosure(enclosure)
    self.file_size = enclosure['length'].to_i
    self.mime_type = enclosure['type']
    self.href = enclosure['url']
    self
  end

  def replace_resources!
    episode.with_lock do
      episode.enclosures.where("created_at < ? AND id != ?", created_at, id).destroy_all
    end
  end
end
