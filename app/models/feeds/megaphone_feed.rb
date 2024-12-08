class Feeds::MegaphoneFeed < Feed
  has_one :megaphone_config, class_name: "::Megaphone::Config", dependent: :destroy, autosave: true, validate: true, inverse_of: :feed

  after_initialize :set_defaults

  alias_method :config, :megaphone_config

  accepts_nested_attributes_for :megaphone_config, allow_destroy: true, reject_if: :all_blank

  def self.model_name
    Feed.model_name
  end

  def integration_type
    :megaphone
  end

  def set_defaults
    self.slug = "prx-#{id}"
    self.title = podcast&.title
    self.private = true

    super
  end

  def publish_integration?
    publish_to_megaphone?
  end

  def publish_integration!
    if publish_integration?
      Publisher.new(self).publish!
    end
  end

  def publish_to_megaphone?
    valid? && persisted? && config&.publish_to_megaphone?
  end

  def mark_as_not_delivered!(episode)
    episode.episode_delivery_statuses.megaphone.first&.mark_as_not_delivered!
  end
end
