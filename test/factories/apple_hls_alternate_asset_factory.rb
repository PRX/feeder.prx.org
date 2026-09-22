FactoryBot.define do
  factory :apple_hls_alternate_asset, class: Apple::HlsAlternateAsset do
    episode
    feeder_podcast { episode.podcast }
    sequence(:apple_show_id) { |n| "show-#{n}" }
    feeder_guid { episode.item_guid }
    status { :staged }
    sequence(:staged_alternate_asset_id) { |n| "staged-#{n}" }
    content_url { "https://example.com/hls/index.m3u8" }
  end
end
