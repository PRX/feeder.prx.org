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
    podcast.feeds.each { |feed| publish_apple(podcast, feed) }
    podcast.feeds.each { |feed| publish_rss(podcast, feed) }
    PublishingPipelineState.complete!(podcast)
  rescue Apple::AssetStateTimeoutError => e
    fail_state(podcast, "apple_timeout", e)
  rescue => e
    fail_state(podcast, "error", e)
  ensure
    PublishingPipelineState.settle_remaining!(podcast)
  end

  def publish_apple(podcast, feed)
    return unless feed.publish_to_apple?

    res = PublishAppleJob.do_perform(podcast.apple_config)
    PublishingPipelineState.publish_apple!(podcast)
    res
  rescue Apple::AssetStateTimeoutError => e
    # Not strictly a 'fail state' because we want to retry this job
    PublishingPipelineState.error_apple!(podcast)
    Rails.logger.send(e.log_level, e.message, {podcast_id: podcast.id})
    NewRelic::Agent.notice_error(e)
    raise e if podcast.apple_config.sync_blocks_rss
  rescue => e
    if podcast.apple_config.sync_blocks_rss
      fail_state(podcast, "apple", e)
    else
      Rails.logger.error("Error publishing to Apple, but continuing to publish RSS", {podcast_id: podcast.id, error: e.message})
      PublishingPipelineState.error_apple!(podcast)
    end
  end

  def publish_rss(podcast, feed)
    res = save_file(podcast, feed)
    PublishingPipelineState.publish_rss!(podcast)
    res
  rescue => e
    fail_state(podcast, "rss", e)
  end

  def apple_timeout_log_level(error)
    error.try(:log_level) || :error
  end

  def fail_state(podcast, type, error)
    (pipeline_method, log_level, raise_exception) =
      case type
      when "apple" then [:error_apple!, :warn, true]
      when "rss" then [:error_rss!, :warn, true]
      when "apple_timeout"
        level = apple_timeout_log_level(error)
        [:retry!, level, %i[error fatal].include?(level)]
      when "error" then [:error!, :error, true]
      end

    PublishingPipelineState.public_send(pipeline_method, podcast)
    Rails.logger.send(log_level, error.message, {podcast_id: podcast.id})
    raise error if raise_exception
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
