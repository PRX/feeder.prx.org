class PublishAppleJob < ApplicationJob
  queue_as :feeder_publishing

  def self.publish_to_apple(apple_config)
    apple_config.build_publisher.publish!
  end

  def self.do_perform(apple_config)
    if !apple_config.publish_to_apple?
      logger.info "Skipping publish to apple for #{apple_config.class.name} #{apple_config.id}"
      return
    end

    publish_to_apple(apple_config)
  end

  def perform(apple_config)
    self.class.do_perform(apple_config)
  end
end
