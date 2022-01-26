FactoryGirl.define do
  factory :feed do
    sequence(:slug) { |n| "myfeed#{n}" }
    file_name 'feed-rss.xml'

    url 'http://feeds.feedburner.com/thornmorris'
    new_feed_url 'http://feeds.feedburner.com/newthornmorris'

    factory :default_feed do
      slug nil
      file_name 'feed-rss.xml'
    end
  end
end
