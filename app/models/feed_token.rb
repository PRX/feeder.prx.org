class FeedToken < ApplicationRecord
  belongs_to :feed, touch: true, optional: true

  validates :token, presence: true, uniqueness: {scope: :feed_id}
  validates_format_of :token, with: /\A[0-9a-zA-Z_.-]+\z/
  validates :label, presence: true

  after_initialize :set_defaults
  before_destroy :protect_last_apple_delivery_token

  def set_defaults
    self.token ||= SecureRandom.urlsafe_base64(20)
  end

  def published_url
    feed.published_url(token)
  end

  private

  def protect_last_apple_delivery_token
    return if destroyed_by_association
    return unless feed&.private? && feed.delegated_delivery_config
    return if feed.delegated_delivery_config.marked_for_destruction?
    return if feed.tokens.any? { |other| other != self && !other.marked_for_destruction? && !other.destroyed? }

    errors.add(:base, "Cannot delete the last token while delegated delivery is attached")
    throw :abort
  end
end
