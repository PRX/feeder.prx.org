require 'active_support/concern'

module ImageFile
  extend ActiveSupport::Concern

  included do
    before_validation :detect_image_attributes

    validates :url, presence: true

    validates :format, inclusion: { in: ['jpeg', 'png', 'gif'] }
  end

  def url=(url)
    super
    reset_image_attributes if url_changed?
  end

  def reset_image_attributes
    self.format = nil
    self.height = nil
    self.width = nil
    self.size = nil
  end

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
