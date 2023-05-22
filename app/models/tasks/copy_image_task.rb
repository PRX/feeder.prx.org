class Tasks::CopyImageTask < ::Task
  before_save :update_image, if: ->(t) { t.status_changed? && t.image }

  def image
    owner
  end

  def podcast
    image&.episode&.podcast || image&.podcast
  end

  def source_url
    image.href
  end

  def porter_tasks
    [
      {
        Type: "Inspect"
      },
      {
        Type: "Copy",
        Mode: "AWS/S3",
        BucketName: ENV["FEEDER_STORAGE_BUCKET"],
        ObjectKey: porter_escape(image.path),
        ContentType: "REPLACE",
        Parameters: {
          CacheControl: "max-age=86400",
          ContentDisposition: "attachment; filename=\"#{porter_escape(image.file_name)}\""
        }
      }
    ]
  end

  def update_image
    image.status = status

    if complete?
      info = porter_callback_inspect
      image.size = porter_callback_size

      # only return for actual images - not detected images in id3 tags
      if info[:Image] && porter_callback_mime&.starts_with?("image/")
        image.format = info[:Image][:Format]
        image.height = info[:Image][:Height].to_i
        image.width = info[:Image][:Width].to_i
      end

      # change status, if metadata doesn't pass validations
      image.status = "invalid" if image.invalid?
    end

    image.save!
    podcast&.publish! if image.status_complete?
  end
end
