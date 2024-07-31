class Tasks::CopyTranscriptTask < ::Task
  before_save :update_transcript, if: ->(task) { task.status_changed? && task.transcript }

  def transcript
    owner
  end

  def source_url
    transcript.href
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
        ObjectKey: porter_escape(transcript.path),
        ContentType: "REPLACE",
        Parameters: {
          CacheControl: "max-age=86400",
          ContentDisposition: "attachment; filename=\"#{porter_escape(transcript.file_name)}\""
        }
      }
    ]
  end

  def update_transcript
    transcript.status = status

    if complete?
      transcript.file_size = porter_callback_size
      transcript.mime_type = porter_callback_mime

      # change status, if metadata doesn't pass validations
      transcript.status = "invalid" if transcript.invalid?
    end

    transcript.save!
  end
end
