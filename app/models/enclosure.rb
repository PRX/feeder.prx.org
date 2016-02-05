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
  end

  def update_attributes_with_enclosure(enclosure)
    self.file_size    = enclosure['length'].to_i
    self.mime_type    = enclosure['type']
    self.original_url = enclosure['url']
    self
  end

  def update_from_fixer(fixer_task)
    super(fixer_task)
    replace_resources!
  end

  def replace_resources!
    episode.with_lock do
      episode.enclosures.where("created_at < ? AND id != ?", created_at, id).destroy_all
    end
  end
end
