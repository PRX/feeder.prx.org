require "builder"

class PublishFeedJob < ApplicationJob
  queue_as :feeder_publishing

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss, :put_object, :copy_object

  def perform(podcast, pub_item)
    Rails.logger.tagged("publish-feed-job:#{podcast.id}") do
      set_job_id_on_publishing_item(podcast)

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
  end

  def publish_integration(podcast, feed)
    return unless feed.publish_integration?
    res = feed.publish_integration!
    PublishingPipelineState.publish_integration!(podcast)
    res
  rescue Apple::AssetStateTimeoutError => e
    # Apple timeout errors indicate the async publishing job is still in progress
    # We always mark the integration as errored in the pipeline state
    PublishingPipelineState.error_integration!(podcast)

    if feed.config.sync_blocks_rss
      # When sync_blocks_rss is enabled, Apple publishing must succeed before RSS
      # Log at the error's specified level and raise RetryPublishingError to retry the entire pipeline
      Rails.logger.send(e.log_level, e.message, {podcast_id: podcast.id})
      raise Apple::RetryPublishingError.new(e.message)
    else
      # When sync_blocks_rss is disabled, we allow RSS publishing to continue despite timeout
      # The integration error is recorded in pipeline state but doesn't block RSS delivery
      Rails.logger.info("Apple publishing timed out, continuing to RSS", {podcast_id: podcast.id})
    end
  rescue => e
    # All other integration errors (network failures, API errors, etc.)
    PublishingPipelineState.error_integration!(podcast)

    # Re-raise the error if sync_blocks_rss is enabled, blocking RSS publishing
    # Otherwise, swallow the error and allow RSS publishing to proceed
    raise e if feed.config.sync_blocks_rss
  end

  def publish_rss(podcast, feed)
    rss_builder = save_file(podcast, feed)
    after_publish_rss(podcast, feed, rss_builder.episodes)
    PublishingPipelineState.publish_rss!(podcast)
    rss_builder
  rescue => e
    PublishingPipelineState.error_rss!(podcast)
    raise e
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

  private

  def set_job_id_on_publishing_item(podcast)
    current_pub_item = PublishingQueueItem.current_unfinished_item(podcast)

    return unless current_pub_item && current_pub_item.job_id.nil?

    current_pub_item.update!(job_id: job_id)
  end
end
