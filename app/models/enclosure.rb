class Enclosure < MediaResource
  def self.build_from_enclosure(episode, enclosure)
    new.tap do |e|
      e.episode = episode
      e.update_enclosure_attributes(enclosure)
    end
  end

  def update_with_enclosure!(enclosure)
    update_enclosure_attributes(enclosure)
    save!
    self
  end

  def update_enclosure_attributes(enclosure)
    self.file_size = enclosure["length"].to_i
    self.mime_type = enclosure["type"]
    self.medium = (enclosure["type"] || "").split("/").first
    self.href = enclosure["url"]
    self
  end

  def replace_resources!
    Enclosure.where(episode_id: episode_id).where.not(id: id).touch_all(:replaced_at, :deleted_at)
  end
end
