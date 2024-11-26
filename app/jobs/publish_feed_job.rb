require "builder"

class PublishFeedJob < ApplicationJob
  queue_as :feeder_publishing

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss, :put_object, :copy_object

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
  rescue => e
    if feed.config.sync_blocks_rss
      fail_state(podcast, feed.integration_type, e)
    else
      Rails.logger.error("Error publishing to #{feed.integration_type}, but continuing to publish RSS", {podcast_id: podcast.id, error: e.message})
      PublishingPipelineState.error_integration!(podcast)
    end
  end

  def publish_rss(podcast, feed)
    res = save_file(podcast, feed)
    PublishingPipelineState.publish_rss!(podcast)
    res
  rescue => e
    fail_state(podcast, "rss", e)
  end

  def fail_state(podcast, type, error)
    (pipeline_method, log_level) = case type
    when "apple_timeout", "error" then [:error!, :error]
    when "rss" then [:error_rss!, :warn]
    else [:error_integration!, :warn]
    end

    PublishingPipelineState.public_send(pipeline_method, podcast)
    Rails.logger.send(log_level, error.message, {podcast_id: podcast.id})
    raise error
  end

  def save_file(podcast, feed, options = {})
    rss = FeedBuilder.new(podcast, feed).to_feed_xml
    opts = default_options.merge(options)
    opts[:body] = rss
    opts[:bucket] = s3_bucket
    opts[:key] = feed.path
    @put_object = s3_client.put_object(opts)
  end

  def default_options
    {
      content_type: "application/rss+xml; charset=UTF-8",
      cache_control: "max-age=60"
    }
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
