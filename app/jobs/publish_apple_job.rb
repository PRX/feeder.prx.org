class PublishAppleJob < ApplicationJob
  queue_as :publish_artifacts

  def self.publish_to_apple(apple_config)
    apple_config.build_publisher.publish!
  end

  def perform(apple_config)
    if !apple_config.publish_to_apple?
      logger.info "Skipping publish to apple for #{apple_config.class.name} #{apple_config.id}"
      return
    end

    self.class.publish_to_apple(apple_config)
  end
end
