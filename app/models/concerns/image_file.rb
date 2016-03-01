require 'active_support/concern'

module ImageFile
  extend ActiveSupport::Concern

  included do
    has_one :task, as: :owner

    before_validation :detect_image_attributes

    before_validation :guid

    validates :original_url, presence: true

    validates :format, inclusion: { in: ['jpeg', 'png', 'gif', nil] }

    after_commit :copy_original_image

    attr_accessor :copy_original
  end

  # need to implement these for your image classes
  def destination_path
  end

  def published_url
  end

  def guid
    self[:guid] ||= SecureRandom.uuid
    self[:guid]
  end

  def copy_original_image
    return if task && !copy_original
    self.copy_original = false
    Tasks::CopyAudioTask.create! do |task|
      task.options = copy_options
      task.owner = self
    end.start!
  end

  def copy_options
    {
      source: original_url,
      destination: destination_path
    }
  end

  def task_complete
    update_attributes!(url: published_url)
  end

  def url
    self[:url] || self[:original_url]
  end

  def original_url=(url)
    super
    if original_url_changed?
      reset_image_attributes
      self.copy_original = true
    end
    self[:original_url]
  end

  def reset_image_attributes
    self.format = nil
    self.height = nil
    self.width = nil
    self.size = nil
  end

  def detect_image_attributes
    return if !original_url || (width && height && format)
    info = FastImage.new(original_url)
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
