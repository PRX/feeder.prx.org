FactoryGirl.define do
  factory :feed do
    sequence(:slug) { |n| "myfeed#{n}" }
    file_name 'feed-rss.xml'
    audio_format { Hash(f: 'flac', b: 16, c: 2, s: 44100) }
    url 'http://feeds.feedburner.com/thornmorris'
    new_feed_url 'http://feeds.feedburner.com/newthornmorris'
    enclosure_template { Feed.enclosure_template_default }
    enclosure_prefix ''

    factory :default_feed do
      slug nil
      file_name 'feed-rss.xml'
      private false
      audio_format { Hash(f: 'mp3', b: 128, c: 2, s: 44100) }
      enclosure_template 'http://www.podtrac.com/pts/redirect{extension}/media.blubrry.com/transistor/{host}{+path}'
      enclosure_prefix ''
    end
  end
end
