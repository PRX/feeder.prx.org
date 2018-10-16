FactoryGirl.define do
  factory :podcast_import do
    account
    user
    series
    feed_episode_count 10

    url 'http://feeds.prx.org/transistor_stem'
  end
end
