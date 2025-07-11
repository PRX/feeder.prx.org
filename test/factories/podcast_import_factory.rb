FactoryBot.define do
  factory :podcast_import do
    podcast
    feed_episode_count { 10 }

    url { "http://feeds.prx.org/transistor_stem" }

    factory :podcast_timings_import, class: PodcastTimingsImport do
    end

    factory :podcast_rss_import, class: PodcastRssImport do
    end

    factory :podcast_megaphone_import, class: PodcastMegaphoneImport do
    end
  end
end
