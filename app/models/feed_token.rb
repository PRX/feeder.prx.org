class FeedToken < ApplicationRecord
  belongs_to :feed, touch: true, optional: true

  validates :token, presence: true, uniqueness: {scope: :feed_id}
  validates_format_of :token, with: /\A[0-9a-zA-Z_.-]+\z/
  validates :label, presence: true

  after_initialize :set_defaults

  def set_defaults
    self.token ||= SecureRandom.urlsafe_base64(20)
  end

  def published_url
    feed.published_url(token)
  end
end
