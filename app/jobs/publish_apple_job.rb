class PublishAppleJob < ApplicationJob
  queue_as :feeder_default

  def self.publish_to_apple(apple_config)
    apple_config.build_publisher.publish!
  end

  def perform(apple_config)
    return unless apple_config.publish_to_apple?

    self.class.publish_to_apple(apple_config)
  end
end
