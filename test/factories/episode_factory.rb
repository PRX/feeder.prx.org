FactoryBot.define do
  factory :episode do
    podcast
    sequence(:prx_uri) { |n| "/api/v1/stories/#{87683 + n}" }
    sequence(:prx_audio_version_uri) { |n| "/api/v1/audio_versions/#{484848 + n}" }

    sequence(:season_number) { |n| n * 2 }
    sequence(:episode_number) { |n| n }
    sequence(:guid) { |n| "ba047dce-9df5-4132-a04b-31d24c7c55a#{n}" }
    sequence(:title) { |n| "Episode #{n}" }
    sequence(:clean_title) { |n| "Clean title #{n}" }
    sequence(:published_at) { |n| Date.today - n.days }

    description do
      "<div><a href=\"/tina\">Tina</a> McElroy Ansa is a little girl when her father's business goes under.</div>"
    end

    factory :episode_with_media do
      audio_version { "One segment audio" }
      segment_count { 1 }
      medium { "audio" }

      contents { [association(:content, status: "complete")] }
      images { [association(:episode_image, status: "complete")] }
    end

    factory :video_episode do
      segment_count { 2 }
      medium { "video" }

      contents do
        [
          association(:content, status: "complete", position: 1, original_url: "s3://prx-testing/video1.mp4/preview.mp3"),
          association(:content, status: "complete", position: 2, original_url: "s3://prx-testing/video1.mp4/preview.mp3")
        ]
      end

      alternate_media_resource do
        association(:alternate_media_resource, status: "complete", original_url: "s3://prx-testing/video1.mp4")
      end
    end
  end
end
