FactoryBot.define do
  factory :oxbow_job_id, class: String do
    Id { "1234/5678/2025-12-17T15:00Z/2025-12-17T16:00Z/27a8112d-b582-4d23-8d73-257e543d64a4.mp3" }
    initialize_with { attributes.with_indifferent_access }
  end

  factory :oxbow_job_received, class: Hash do
    Time { "2025-12-17T14:51:16.490Z" }
    Timestamp { 1765983076.49 }
    JobReceived do
      Job { build(:oxbow_job_id) }
      Execution { {Id: "arn:aws:states:the-execution-arn"} }
      State "RECEIVED"
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :oxbow_ffmpeg_destination, class: Hash do
    Mode { "AWS/S3" }
    BucketName { "prx-feed-testing" }
    ObjectKey { "1234/5678/2025-12-17T15:00Z/2025-12-17T16:00Z/27a8112d-b582-4d23-8d73-257e543d64a4.mp3" }
    initialize_with { attributes.with_indifferent_access }
  end

  factory :oxbow_ffmpeg_task, class: Hash do
    Type { "FFmpeg" }
    FFmpeg do
      Inputs { "-t 4350 -i \"http://some.stream/url/stream_name.mp3\"" }
      GlobalOptions { "" }
      InputFileOptions { "" }
      OutputFileOptions { "" }
      Outputs { [{Format: "mp3", Destination: build(:oxbow_ffmpeg_destination)}] }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :oxbow_ffmpeg_result, class: Hash do
    Task { "FFmpeg" }
    Time { "2025-12-17T16:02:23.826Z" }
    Timestamp { 1765987343.826 }
    FFmpeg do
      {
        Outputs: [
          {
            Mode: "AWS/S3",
            BucketName: "prx-feed-testing",
            ObjectKey: "1234/5678/2025-12-17T15:00Z/2025-12-17T16:00Z/27a8112d-b582-4d23-8d73-257e543d64a4.mp3",
            Duration: 4320000,
            Size: 12345678,
            StartEpoch: 1765983321
          }
        ]
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :oxbow_task_result, class: Hash do
    Time { "2025-12-17T16:02:23.210Z" }
    Timestamp { 1765987343.21 }
    Task { build(:oxbow_ffmpeg_task) }
    TaskResult do
      Job { build(:oxbow_job_id) }
      Execution { {Id: "arn:aws:states:the-execution-arn"} }
      Result build(:oxbow_ffmpeg_result)
    end
    initialize_with { attributes.with_indifferent_access }
  end

  factory :oxbow_job_results, class: Hash do
    Time { "2025-12-17T16:02:23.826Z" }
    Timestamp { 1765987343.826 }
    JobResult do
      {
        Job: build(:oxbow_job_id),
        Execution: {Id: "arn:aws:states:the-execution-arn"},
        State: "DONE",
        FailedTasks: [],
        TaskResults: [build(:oxbow_ffmpeg_result)]
      }
    end
    initialize_with { attributes.with_indifferent_access }
  end
end
