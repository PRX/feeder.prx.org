FactoryGirl.define do
  factory :copy_media_task, class: Tasks::CopyMediaTask do
    association :owner, factory: :enclosure
    status :complete
    job_id '1234'
    options destination: 's3://test-prx-up/podcast/episode/filename.mp3'
    result do
      {
        Time: Time.now.iso8601,
        Timestamp: Time.now.to_f,
        JobResult: {
          Job: {Id: '1234'},
          Execution: {Id: 'arn:aws:states:us-east-1:5678'},
          Result: [
            {
              Time: Time.now.iso8601,
              Timestamp: Time.now.to_f,
              Task: 'Copy',
              Mode: 'AWS/S3',
              BucketName: 'test-prx-up',
              ObjectKey: 'podcast/episode/filename.mp3'
            },
            {
              Time: Time.now.iso8601,
              Timestamp: Time.now.to_f,
              Task: 'Inspect',
              Inspection: {
                Size: 14566355,
                Audio: {
                  Duration: 48352,
                  Format: 'mp3',
                  Bitrate: '128000',
                  Frequency: '44100',
                  Channels: 1,
                  Layout: 'mono',
                  Layer: 3,
                  Samples: nil,
                  Frames: '34931'
                },
                Extension: 'mp3',
                MIME: 'audio/mpeg'
              }
            }
          ]
        }
      }
    end
  end

  factory :copy_image_task, class: Tasks::CopyImageTask do
    association :owner, factory: :episode_image_with_episode
    status :complete
    job_id '2345'
    result do
      {
        Time: Time.now.iso8601,
        Timestamp: Time.now.to_f,
        JobResult: {
          Job: {Id: '2345'},
          Execution: {Id: 'arn:aws:states:us-east-1:6789'},
          Result: [
            {
              Time: Time.now.iso8601,
              Timestamp: Time.now.to_f,
              Task: 'Copy',
              Mode: 'AWS/S3',
              BucketName: 'test-prx-up',
              ObjectKey: 'podcast/episode/filename.png'
            }
          ]
        }
      }
    end
  end
end
