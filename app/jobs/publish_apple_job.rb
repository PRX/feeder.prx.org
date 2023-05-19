class PublishAppleJob < ApplicationJob
  queue_as :feeder_default

  def perform(apple_config)
    publisher = apple_config.build_publisher
    publisher.publish!
  end
end
