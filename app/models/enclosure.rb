class Enclosure < MediaResource
  def self.build_from_enclosure(enclosure)
    new.update_attributes_with_enclosure(enclosure)
  end

  def update_with_enclosure(enclosure)
    update_attributes_with_enclosure(enclosure)
    save
  end

  def update_attributes_with_enclosure(enclosure)
    self.file_size = enclosure['length'].to_i
    self.mime_type = enclosure['type']
    self.url       = enclosure['url']
    self
  end
end
