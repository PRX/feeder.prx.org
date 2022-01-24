class FeedsController < ApplicationController
  def index
    max_updated_at = Feed.maximum(:updated_at)

    json = Rails.cache.fetch("feeds_json/#{max_updated_at}") do
      podcasts = Podcast.includes(feeds: :feed_tokens).reject(&:default_feed_settings?)
      podcasts_json(podcasts).to_json
    end

    render json: json
  end

  private

  def podcasts_json(podcasts)
    podcasts.map { |p| [p.id, podcast_json(p)] }.to_h
  end

  def podcast_json(podcast)
    podcast.
      slice(:id, :title).
      merge(defaultFeed: feed_json(podcast.feeds.find(&:default?))).
      merge(feeds: feeds_json(podcast.feeds.reject(&:default?)))
  end

  def feeds_json(feeds)
    feeds.map { |f| [f.slug, feed_json(f)] }.to_h
  end

  def feed_json(feed)
    feed.
      slice(:private, :filter_zones, :audio_format).
      transform_keys { |k| k.camelize(:lower) }.
      merge(tokens: feed.tokens.map { |t| token_json(t) } )
  end

  def token_json(token)
    token.
      slice(:label, :token, :expires_at).
      transform_keys { |k| k.camelize(:lower) }
  end
end
