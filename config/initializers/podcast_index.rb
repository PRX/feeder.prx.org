PodcastIndex.configure do |config|
  config.api_key = ENV["PODCAST_INDEX_API_KEY"]
  config.api_secret = ENV["PODCAST_INDEX_API_SECRET"]
end
