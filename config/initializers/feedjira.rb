load "#{Rails.root}/lib/feedjira/parser/podcast.rb"

Feedjira.configure do |config|
  config.parsers.unshift(Feedjira::Parser::Podcast)
end
