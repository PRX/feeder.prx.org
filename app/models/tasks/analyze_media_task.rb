class Tasks::AnalyzeMediaTask < ::Task
  before_save :update_media_resource, if: ->(t) { t.status_changed? && t.media_resource }

  def media_resource
    owner
  end

  def source_url
    media_resource.original_url
  end

  def porter_tasks
    [{Type: "Inspect"}]
  end

  def update_media_resource
    media_resource.status = status

    if complete?
      info = porter_callback_inspect
      media_resource.mime_type = porter_callback_mime
      media_resource.medium = (media_resource.mime_type || "").split("/").first
      media_resource.file_size = porter_callback_size

      if info[:Audio]
        media_resource.sample_rate = info[:Audio][:Frequency].to_i
        media_resource.channels = info[:Audio][:Channels].to_i
        media_resource.duration = info[:Audio][:Duration].to_f / 1000
        media_resource.bit_rate = info[:Audio][:Bitrate].to_i / 1000
      end

      # only return for actual videos - not detected images in id3 tags
      if info[:Video] && media_resource.mime_type&.starts_with?("video")
        media_resource.duration = info[:Video][:Duration].to_f / 1000
        media_resource.width = info[:Video][:Width].to_i
        media_resource.height = info[:Video][:Height].to_i
        media_resource.frame_rate = info[:Video][:Framerate].to_f.round
      end
    end

    media_resource.save!
  end
end
