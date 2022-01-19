class Feed < BaseModel
  belongs_to :podcast, -> { with_deleted }

  has_many :feed_tokens, dependent: :destroy

  scope :default, -> { where(slug: nil) }

  def default?
    slug.nil?
  end
end
