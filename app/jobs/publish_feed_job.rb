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
    handle_apple_timeout_error(podcast, e)
  rescue => e
    handle_error(podcast, e)
  ensure
    PublishingPipelineState.settle_remaining!(podcast)
  end

  def handle_apple_timeout_error(podcast, asset_timeout_error)
    PublishingPipelineState.retry!(podcast)
    Rails.logger.send(asset_timeout_error.log_level) do
      [
        "Asset processing timeout",
        {
          podcast_id: podcast.id,
          error: asset_timeout_error.message,
          backtrace: asset_timeout_error&.backtrace&.join("\n")
        }
      ]
    end
  end

  def handle_error(podcast, error)
    PublishingPipelineState.error!(podcast)
    # Two error log lines here.
    # 1) the error message and backtrace:
    Rails.logger.error("Error publishing podcast", {podcast_id: podcast.id, error: error.message, backtrace: error&.backtrace&.join("\n")})
    # 2) The second is from the job handler, which logs an error when this excetion is raised:
    raise error
  end

  def publish_apple(podcast, feed)
    return unless feed.publish_to_apple?

    begin
      res = PublishAppleJob.do_perform(podcast.apple_config)
      PublishingPipelineState.publish_apple!(podcast)
      res
    rescue => e
      handle_apple_error(podcast, e)
    end
  end

  def handle_apple_error(podcast, error)
    PublishingPipelineState.error_apple!(podcast)
    NewRelic::Agent.notice_error(error)
    raise error
  end

  def publish_rss(podcast, feed)
    res = save_file(podcast, feed)
    PublishingPipelineState.publish_rss!(podcast)
    res
  rescue => e
    handle_rss_error(podcast, feed, e)
  end

  def handle_rss_error(podcast, feed, error)
    PublishingPipelineState.error_rss!(podcast)
    Rails.logger.error("Error publishing RSS", {podcast_id: podcast.id, feed_id: feed.id, error: error.message, backtrace: error&.backtrace&.join("\n")})
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
