class FeedToken < ApplicationRecord
  belongs_to :feed, touch: true, optional: true

  validates :token, presence: true, uniqueness: {scope: :feed_id}
  validates_format_of :token, with: /\A[0-9a-zA-Z_.-]+\z/
  validates :label, presence: true

  after_initialize :set_defaults

  def set_defaults
    self.token ||= SecureRandom.urlsafe_base64(20)
  end

  def self.feed_published_url_with_token(some_feed)
    raise "missing token for private feed" unless some_feed.tokens.any?

    token = some_feed.tokens.first.token

    # use the feed's published_url, but replace the path with the token using substitution
    some_feed
      .published_url
      .sub("{?auth}", "?auth=#{token}")
  end
end
