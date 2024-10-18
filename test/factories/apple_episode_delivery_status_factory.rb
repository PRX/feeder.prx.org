FactoryBot.define do
  factory :apple_episode_delivery_status, class: "Apple::EpisodeDeliveryStatus" do
    association :episode

    delivered { false }
    asset_processing_attempts { 0 }
    source_url { "http://example.com/audio.mp3" }
    source_size { 1_048_576 } # 1 MB
    source_filename { "episode_audio.mp3" }
    enclosure_url { "http://cdn.example.com/audio.mp3" }
    source_media_version_id { 1 }
    source_fetch_count { 0 }
  end
end
