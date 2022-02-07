FactoryGirl.define do
  factory :feed do
    sequence(:slug) { |n| "myfeed#{n}" }
    file_name 'feed-rss.xml'

    url 'http://feeds.feedburner.com/thornmorris'
    new_feed_url 'http://feeds.feedburner.com/newthornmorris'
    audio_format { Hash(f: 'mp3', b: 128, c: 2, s: 44100) }

    factory :default_feed do
      slug nil
      file_name 'feed-rss.xml'
      private false
      audio_format { Hash(f: 'flac', b: 16, c: 2, s: 44100) }
    end
  end
end
