require "builder"

class PublishPublicFeedJob < ApplicationJob
  queue_as :feeder_publishing

  include PodcastsHelper

  attr_writer :publish_feed_job

  def perform(podcast)
    publish_feed_job.save_file(podcast, podcast.public_feed)
  end

  def publish_feed_job
    @publish_feed_job ||= PublishFeedJob.new
  end
end
