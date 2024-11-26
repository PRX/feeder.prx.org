class Feeds::MegaphoneFeed < Feed
  has_one :megaphone_config, class_name: "::Megaphone::Config", inverse_of: :feed

  alias_method :config, :megaphone_config

  def self.model_name
    Feed.model_name
  end

  def integration_type
    :megaphone
  end

  def publish_integration?
    megaphone_config&.publish_to_megaphone?
  end

  def publish_integration!
    if publish_integration?
      megaphone_config.build_publisher.publish!
    end
  end

  def mark_as_not_delivered!(episode)
    episode.episode_delivery_statuses.megaphone.first&.mark_as_not_delivered!
  end
end
