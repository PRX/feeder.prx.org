FactoryBot.define do
  factory :apple_config, class: Apple::Config do
    publish_enabled { true }
    sync_blocks_rss { true }
    key { build(:apple_key) }
    podcast

    # set up the private and public feeds
    before(:create) do |apple_config, evaluator|
      apple_config.public_feed ||= create(:feed, podcast: evaluator.podcast)
      apple_config.private_feed ||= create(:feed, podcast: evaluator.podcast)
    end
  end
end
