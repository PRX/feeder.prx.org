class Content < MediaResource
  acts_as_list scope: :episode

  def self.build_from_content(episode, content)
    new.update_attributes_with_content(content).tap { |c| c.episode = episode }
  end

  def update_with_content(content)
    update_attributes_with_content(content)
    save
  end

  def update_attributes_with_content(content)
    %w( medium expression channels duration height width lang).each do |at|
      self.try("#{at}=", content[at])
    end

    self.original_url = content['url']
    self.mime_type    = content['type']
    self.file_size    = content['file_size'].to_i
    self.bit_rate     = content['bitrate'].to_i
    self.frame_rate   = content['framerate'].to_i
    self.sample_rate  = content['samplingrate'].to_f * 1000
    self.is_default   = content['is_default'] && content['is_default'].downcase == 'true'
    self
  end
end
