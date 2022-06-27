class FeedToken < BaseModel
  belongs_to :feed, touch: true

  validates :token, presence: true, uniqueness: { scope: :feed_id }
  validates_format_of :token, with: /\A[0-9a-zA-Z_.-]+\z/

  after_initialize :set_defaults

  def set_defaults
    self.token ||= SecureRandom.urlsafe_base64(20)
  end

  def feed_published_url_with_token
    feed.published_url + '?auth=' + token
  end
end
