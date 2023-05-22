load "#{Rails.root}/lib/feedjira/parser/podcast.rb"

Feedjira::Feed.add_feed_class Feedjira::Parser::Podcast
