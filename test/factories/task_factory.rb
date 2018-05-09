FactoryGirl.define do
  factory :copy_media_task, class: Tasks::CopyMediaTask do
    association :owner, factory: :enclosure
    status :complete
    options destination: 's3://test-prx-up/podcast/episode/filename.mp3'
    result task: {
      result_details: {
        info: {
            size: 774059,
            content_type: 'audio/mpeg',
            format: 'mp3',
            channel_mode: 'Mono',
            channels: 1,
            bit_rate: 128,
            length: 48.352653,
            sample_rate: 44100
        }
      }
    }
  end

  factory :copy_image_task, class: Tasks::CopyImageTask do
    association :owner, factory: :episode_image_with_episode
    status :complete
    result task: {
      result_details: {
        info: {
            size: 774059,
            content_type: 'image/png'
        }
      }
    }
  end
end
