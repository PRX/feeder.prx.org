class FeedImage < ActiveRecord::Base
  belongs_to :podcast

  before_validation :detect_image_attributes

  validates :link, :url, :title, presence: true

  validates :format, inclusion: { in: ['jpeg', 'png', 'gif'] }

  validates :height, :width, numericality: { less_than: 2048 }

  def detect_image_attributes
    return if !url || (width && height && format)
    info = FastImage.new(url)
    self.dimensions = info.size
    self.format = info.type
    self.size = info.content_length
  end

  def dimensions
    [width, height]
  end

  def dimensions=(s)
    self.width, self.height = s
  end
end
