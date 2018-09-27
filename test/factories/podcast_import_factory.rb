FactoryGirl.define do
  factory :podcast_import do
    account
    user
    series
    episode_importing_count 10

    url 'http://feeds.prx.org/transistor_stem'
  end
end
