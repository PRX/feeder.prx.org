require "builder"

class PublishFeedJob < ApplicationJob
  queue_as :feeder_publishing

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss, :put_object, :copy_object

  def perform(podcast, pub_item)
    Rails.logger.tagged("publish-feed-job:#{podcast.id}") { perform_publish(podcast, pub_item) }
  end

  def perform_publish(podcast, pub_item)
    set_job_id_on_publishing_item(podcast)

    # Consume the SQS message, return early, if we have racing threads trying to
    # grab the current publishing pipeline.
    return :null if null_publishing_item?(podcast, pub_item)
    return :mismatched if mismatched_publishing_item?(podcast, pub_item)

    publish_pipeline(podcast, pub_item)
  rescue PublishingPipelineState::LostOwnershipError => e
    # Rescued here so it also covers publish_pipeline's own error!/retry!
    # writes. Our pipeline was expired or replaced: stop without writing state
    Rails.logger.warn("Aborting PublishFeedJob, lost pipeline ownership", {podcast_id: podcast.id, publishing_queue_item_id: pub_item.id, error: e.message, cause: e.cause&.message})
  ensure
    PublishingPipelineState.settle_remaining!(podcast)
  end

  def publish_pipeline(podcast, pub_item)
    Rails.logger.info("Starting publishing pipeline via PublishFeedJob", {podcast_id: podcast.id, publishing_queue_item_id: pub_item.id})

    PublishingPipelineState.start!(pub_item)

    # Publish each integration for each feed (e.g. apple, megaphone)
    podcast.feeds.each do |feed|
      feed.integration_types.each { |integration| publish_integration(podcast, pub_item, feed, integration) }
    end

    # After integrations, publish RSS, if appropriate
    podcast.feeds.each { |feed| publish_rss(podcast, pub_item, feed) }

    PublishingPipelineState.complete!(pub_item)
  # Top-level error handling, capping the entire pipeline's error status
  # Intermediate errors are handled by publish_integration and publish_rss
  rescue Apple::RetryPublishingError
    # Terminal state: retry
    PublishingPipelineState.retry!(pub_item)
  rescue => e
    # Terminal state: error. Log first, the error! write can lose ownership.
    Rails.logger.error(e.message, {podcast_id: podcast.id})
    PublishingPipelineState.error!(pub_item)
    raise e
  end

  def publish_integration(podcast, pub_item, feed, integration)
    return unless feed.publish_integration?(integration)

    config = feed.integration_config(integration)
    context = {feed_id: feed.id, integration: integration}
    tags = ["integration:#{integration}", "feed:#{feed.id}"]
    heartbeat = -> { PublishingPipelineState.heartbeat!(pub_item) }

    Rails.logger.tagged(*tags) do
      Rails.logger.info("Starting integration feed publish", context)
      res = feed.publish_integration!(integration, heartbeat: heartbeat)
      PublishingPipelineState.publish_integration!(pub_item)
      Rails.logger.info("Completed integration feed publish", context)
      res
    rescue Apple::AssetStateTimeoutError => e
      # Apple timeout errors indicate the async publishing job is still in progress
      # We always mark the integration as errored in the pipeline state
      PublishingPipelineState.error_integration!(pub_item)

      # Log at the error's specified level (INFO, WARN, or ERROR)
      e.log_error!

      if config.sync_blocks_rss
        raise Apple::RetryPublishingError.new(e.message)
      else
        Rails.logger.info("Apple publishing timed out, continuing to RSS", context)
      end
    rescue => e
      Rails.logger.error("Integration feed publish failed", context.merge(error: e))
      PublishingPipelineState.error_integration!(pub_item)

      # Without sync_blocks_rss, swallow the error so RSS publishing proceeds
      raise e if config.sync_blocks_rss
    end
  end

  def publish_rss(podcast, pub_item, feed)
    rss_builder = save_file(podcast, feed)
    after_publish_rss(podcast, feed, rss_builder.episodes)
    PublishingPipelineState.publish_rss!(pub_item)
    rss_builder
  rescue => e
    PublishingPipelineState.error_rss!(pub_item)
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
