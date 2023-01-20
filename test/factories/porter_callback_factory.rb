FactoryBot.define do
  factory :porter_copy_task, class: Hash do
    Type { "Copy" }
    Mode { "AWS/S3" }
    BucketName { "test-prx-up" }
    ObjectKey { "podcast/episode/filename.mp3" }
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_copy_result, class: Hash do
    Task { "Copy" }
    Other { "Things" }
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_inspect_audio_result, class: Hash do
    Task { "Inspect" }
    Inspection do
      {
        Extension: "mp3",
        MIME: "audio/mpeg",
        Size: "32980032",
        Audio: {
          Duration: 1371437,
          Format: "mp3",
          Bitrate: "192000",
          Frequency: "48000",
          Channels: 2,
          Layout: "stereo",
          Layer: "3",
          Samples: nil,
          Frames: "57143"
        }
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_inspect_video_result, class: Hash do
    Task { "Inspect" }
    Inspection do
      {
        Extension: "mp4",
        MIME: "video/mp4",
        Size: "16996018",
        Audio: {
          Duration: 158035,
          Format: "aac",
          Bitrate: "109507",
          Frequency: "44100",
          Channels: 2,
          Layout: "stereo"
        },
        Video: {
          Duration: 157991,
          Format: "h264",
          Bitrate: "747441",
          Width: 640,
          Height: 360,
          Aspect: "16:9",
          Framerate: "24000/1001"
        }
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_job_received, class: Hash do
    Time { "2012-12-21T12:34:56Z" }
    Timestamp { 1356093296.0 }
    JobReceived do
      {
        Job: {Id: "the-job-id"},
        State: "RECEIVED"
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_task_result, class: Hash do
    Time { "2012-12-21T12:34:56Z" }
    Timestamp { 1356093296.0 }
    TaskResult do
      {
        Job: {Id: "the-job-id"},
        Result: build(:porter_copy_result),
        Task: build(:porter_copy_task)
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_task_error, class: Hash do
    Time { "2012-12-21T12:34:56Z" }
    Timestamp { 1356093296.0 }
    TaskResult do
      {
        Job: {Id: "the-job-id"},
        Error: {Error: "SomethingBad", Cause: "Something went bad"},
        Task: build(:porter_copy_task)
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_job_results, class: Hash do
    Time { "2012-12-21T12:34:56Z" }
    Timestamp { 1356093296.0 }
    JobResult do
      {
        Job: {Id: "the-job-id"},
        State: "DONE",
        TaskResults: [build(:porter_copy_result), build(:porter_inspect_audio_result)],
        FailedTasks: []
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_job_failed, class: Hash do
    Time { "2012-12-21T12:34:56Z" }
    Timestamp { 1356093296.0 }
    JobResult do
      {
        Job: {Id: "the-job-id"},
        State: "DONE",
        TaskResults: [],
        FailedTasks: [build(:porter_copy_task), build(:porter_inspect_audio_result)]
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :porter_job_ingest_failed, class: Hash do
    Time { "2012-12-21T12:34:56Z" }
    Timestamp { 1356093296.0 }
    JobResult do
      {
        Job: {Id: "the-job-id"},
        State: "SOURCE_FILE_INGEST_ERROR",
        TaskResults: [],
        FailedTasks: []
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end
end
