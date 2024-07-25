FactoryBot.define do
  factory :copy_media_task, class: Tasks::CopyMediaTask do
    association :owner, factory: :content
    status { :complete }
    job_id { "1234" }
    options { {destination: "s3://test-prx-up/podcast/episode/filename.mp3"} }
    result { build(:porter_job_results) }

    factory :copy_uncut_task do
      association :owner, factory: :uncut
    end
  end

  factory :copy_image_task, class: Tasks::CopyImageTask do
    association :owner, factory: :episode_image_with_episode
    status { :complete }
    job_id { "2345" }
    result { build(:porter_image_job_results) }
  end

  factory :copy_transcript_task, class: Tasks::CopyTranscriptTask do
    association :owner, factory: :transcript
    status { :complete }
    job_id { "2345" }
    result { build(:porter_transcript_job_results) }
  end

  factory :fix_media_task, class: Tasks::FixMediaTask do
    association :owner, factory: :content
    status { :complete }
    job_id { "1234" }
    options { {destination: "s3://test-prx-up/podcast/episode/filename.mp3"} }
  end
end
