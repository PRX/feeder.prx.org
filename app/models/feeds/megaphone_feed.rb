class Feeds::MegaphoneFeed < Feed
  DEFAULT_TITLE = "Megaphone Integration"

  has_one :megaphone_config, class_name: "::Megaphone::Config", dependent: :destroy, autosave: true, validate: true, inverse_of: :feed

  validate :must_have_token

  after_initialize :set_defaults

  alias_method :config, :megaphone_config

  accepts_nested_attributes_for :megaphone_config, allow_destroy: true, reject_if: :all_blank

  def paranoia_destroy_attributes
    {
      deleted_at: current_time_from_proper_timezone,
      slug: "#{slug}-#{Time.now.to_i}"
    }
  end

  def must_have_token
    if tokens.blank?
      errors.add(:tokens, "must have a token")
    end
  end

  def self.model_name
    Feed.model_name
  end

  def integration_type
    :megaphone
  end

  def set_defaults
    self.slug = "prx-#{id}"
    self.title = DEFAULT_TITLE
    self.tokens = [FeedToken.new(label: DEFAULT_TITLE)] if tokens.empty?
    self.private = true

    super
  end

  def publish_integration?
    publish_to_megaphone?
  end

  def publish_integration!
    if publish_integration?
      ::Megaphone::Publisher.new(self).publish!
    end
  end

  def publish_to_megaphone?
    valid? && persisted? && config&.publish_to_megaphone?
  end

  def mark_as_not_delivered!(episode)
    episode.episode_delivery_statuses.megaphone.first&.mark_as_not_delivered!
  end
end
