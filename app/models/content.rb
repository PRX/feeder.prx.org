class Content < MediaResource
  acts_as_list scope: :episode

  def self.build_from_content(content)
    new.update_attributes_with_content(content)
  end

  def update_with_content(content)
    update_attributes_with_content(content)
    save
  end

  def update_attributes_with_content(content)
    %w( url medium expression bitrate framerate samplingrate
      channels duration height width lang
    ).each do |at|
      self.try("#{at}=", content[at])
    end

    self.original_url = content['url']
    self.mime_type    = content['type']
    self.file_size    = content['file_size'].to_i
    self.is_default   = content['is_default'] && content['is_default'].downcase == 'true'
    self
  end
end
