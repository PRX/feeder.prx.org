FactoryBot.define do
  factory :episode_delivery_status, class: "Integrations::EpisodeDeliveryStatus" do
    association :episode

    integration { Integrations::EpisodeDeliveryStatus.integrations[:apple] }
    delivered { false }
    asset_processing_attempts { 0 }
    source_url { "http://example.com/audio.mp3" }
    source_size { 1_048_576 } # 1 MB
    source_filename { "episode_audio.mp3" }
    enclosure_url { "http://cdn.example.com/audio.mp3" }
    source_media_version_id { 1 }
    source_fetch_count { 0 }
  end

  factory :apple_episode_delivery_status, class: "Integrations::EpisodeDeliveryStatus" do
    association :episode

    integration { Integrations::EpisodeDeliveryStatus.integrations[:apple] }
    delivered { false }
    asset_processing_attempts { 0 }
    source_url { "http://example.com/audio.mp3" }
    source_size { 1_048_576 } # 1 MB
    source_filename { "episode_audio.mp3" }
    enclosure_url { "http://cdn.example.com/audio.mp3" }
    source_media_version_id { 1 }
    source_fetch_count { 0 }
  end

  factory :megaphone_episode_delivery_status, class: "Integrations::EpisodeDeliveryStatus" do
    association :episode

    integration { Integrations::EpisodeDeliveryStatus.integrations[:megaphone] }
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
