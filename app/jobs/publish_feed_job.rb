require "builder"

class PublishFeedJob < ApplicationJob
  queue_as :feeder_publishing

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss, :put_object, :copy_object

  ERROR_HANDLERS = {
    "rss" => {method: :error_rss!, level: :warn},
    "apple_timeout" => {method: :retry!, level: :info},
    "error" => {method: :error!, level: :error}
  }.freeze

  def perform(podcast, pub_item)
    # Consume the SQS message, return early, if we have racing threads trying to
    # grab the current publishing pipeline.
    return :null if null_publishing_item?(podcast, pub_item)
    return :mismatched if mismatched_publishing_item?(podcast, pub_item)

    Rails.logger.info("Starting publishing pipeline via PublishFeedJob", {podcast_id: podcast.id, publishing_queue_item_id: pub_item.id})

    PublishingPipelineState.start!(podcast)

    # Publish each integration for each feed (e.g. apple, megaphone)
    podcast.feeds.each { |feed| publish_integration(podcast, feed) }

    # After integrations, publish RSS, if appropriate
    podcast.feeds.each { |feed| publish_rss(podcast, feed) }

    PublishingPipelineState.complete!(podcast)
  rescue Apple::AssetStateTimeoutError => e
    # This will cap the pipeline with a :retry state, and the job will be retried
    fail_state(podcast, "apple_timeout", e)
  rescue => e
    fail_state(podcast, "error", e)
  ensure
    PublishingPipelineState.settle_remaining!(podcast)
  end

  def publish_integration(podcast, feed)
    return unless feed.publish_integration?
    res = feed.publish_integration!
    PublishingPipelineState.publish_integration!(podcast)
    res
  rescue Apple::AssetStateTimeoutError => e
    # Not strictly a 'fail state' because we want to retry this job
    PublishingPipelineState.error_integration!(podcast)
    Rails.logger.send(e.log_level, e.message, {podcast_id: podcast.id})
    NewRelic::Agent.notice_error(e)
    # Short circuit the rest of the pipeline if sync_blocks_rss is enabled
    raise e if feed.config.sync_blocks_rss
  rescue => e
    if feed.config.sync_blocks_rss
      fail_state(podcast, feed.integration_type, e)
    else
      Rails.logger.error("Error publishing to #{feed.integration_type}, but continuing to publish RSS", {podcast_id: podcast.id, error: e.message})
      PublishingPipelineState.error_integration!(podcast)
    end
  end

  def publish_rss(podcast, feed)
    rss_builder = save_file(podcast, feed)
    after_publish_rss(podcast, feed, rss_builder.episodes)
    PublishingPipelineState.publish_rss!(podcast)
    rss_builder
  rescue => e
    fail_state(podcast, "rss", e)
  end

  def after_publish_rss(podcast, feed, episodes)
    if feed.default?
      update_first_publish_episodes(first_publish_episodes(episodes))
    end
    notify_rss_published(podcast, feed)
  end

  def save_file(podcast, feed, options = {})
    rss = FeedBuilder.new(podcast, feed)
    opts = default_options.merge(options)
    opts[:body] = rss.to_feed_xml
    opts[:bucket] = s3_bucket
    opts[:key] = feed.path
    @put_object = s3_client.put_object(opts)
    rss
  end

  def first_publish_episodes(episodes)
    Episode.first_publish.where(id: episodes)
  end

  def update_first_publish_episodes(episodes)
    if episodes.count > 10
      episodes.update_all(first_rss_published_at: DateTime.now)
    else
      episodes.each do |episode|
        episode.update(first_rss_published_at: DateTime.now)
        episode.head_request
      end
    end
  end

  def default_options
    {
      content_type: "application/rss+xml; charset=UTF-8",
      cache_control: "max-age=60"
    }
  end

  def apple_timeout_log_level(error)
    error.try(:log_level) || :error
  end

  def should_raise?(error)
    if error.respond_to?(:raise_publishing_error?)
      error.raise_publishing_error?
    else
      true
    end
  end

  def fail_state(podcast, type, error)
    handler = ERROR_HANDLERS[type] || {method: :error_integration!, level: :warn}
    PublishingPipelineState.public_send(handler[:method], podcast)

    log_level = (type == "apple_timeout") ? apple_timeout_log_level(error) : handler[:level]
    Rails.logger.send(log_level, error.message, {podcast_id: podcast.id})

    raise error if should_raise?(error)
  end

  def null_publishing_item?(podcast, pub_item)
    current_pub_item = PublishingQueueItem.current_unfinished_item(podcast)

    null_pub_item = pub_item.nil? || current_pub_item.nil?

    if null_pub_item
      Rails.logger.info("Null publishing_queue_item in PublishFeedJob", {
        podcast_id: podcast.id,
        incoming_publishing_item_id: pub_item&.id,
        current_publishing_item_id: current_pub_item&.id
      })
    end
  end

  def mismatched_publishing_item?(podcast, pub_item)
    current_pub_item = PublishingQueueItem.current_unfinished_item(podcast)

    mismatch = pub_item != current_pub_item

    if mismatch
      Rails.logger.info("Mismatched publishing_queue_item in PublishFeedJob", {
        podcast_id: podcast.id,
        incoming_publishing_item_id: pub_item&.id,
        current_publishing_item_id: current_pub_item&.id
      })
    end

    mismatch
  end
end
