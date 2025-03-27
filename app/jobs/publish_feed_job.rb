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
  # Top-level error handling, capping the entire pipeline's error status
  # All of the intermediate errors are handled in the publish_integration and publish_rss
  rescue Apple::RetryPublishingError => e
    PublishingPipelineState.retry!(podcast)
    Rails.logger.warn(e.message, {podcast_id: podcast.id})
    raise e
  rescue => e
    PublishingPipelineState.error!(podcast)
    Rails.logger.error(e.message, {podcast_id: podcast.id})
    raise e
  ensure
    PublishingPipelineState.settle_remaining!(podcast)
  end

  def publish_integration(podcast, feed)
    return unless feed.publish_integration?
    res = feed.publish_integration!
    PublishingPipelineState.publish_integration!(podcast)
    res
  rescue Apple::ApiPermissionError, Apple::AssetStateTimeoutError => e
    PublishingPipelineState.error_integration!(podcast)

    if feed.config.sync_blocks_rss
      # Handle permission errors with exponential backoff
      if e.raise_publishing_error?(feed)
        Rails.logger.error(e.message, {podcast_id: podcast.id})
        NewRelic::Agent.notice_error(e)
      end

      Rails.logger.send(e.log_level(feed), e.message, {podcast_id: podcast.id})
      raise Apple::RetryPublishingError.new(e.message)
    end
  rescue => e
    PublishingPipelineState.error_integration!(podcast)

    raise e if feed.config.sync_blocks_rss
  end

  def publish_rss(podcast, feed)
    res = save_file(podcast, feed)
    PublishingPipelineState.publish_rss!(podcast)
    res
  rescue => e
    PublishingPipelineState.error_rss!(podcast)
    raise e
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
