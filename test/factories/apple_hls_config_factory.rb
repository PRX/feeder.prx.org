FactoryBot.define do
  factory :apple_hls_config, class: Apple::HlsConfig do
    show_feed_binding { association(:apple_show_feed_binding) }
    enabled { true }
    video_enabled_cache { true }
    last_checked_at { Time.current }
  end
end
