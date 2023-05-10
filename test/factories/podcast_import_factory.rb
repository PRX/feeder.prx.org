FactoryBot.define do
  factory :podcast_import do
    account_id { 123 }
    podcast
    feed_episode_count { 10 }

    url { "http://feeds.prx.org/transistor_stem" }
  end
end
