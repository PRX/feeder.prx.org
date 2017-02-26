require 'active_support/concern'

module ImageFile
  extend ActiveSupport::Concern

  included do
    has_one :task, as: :owner

    before_validation :detect_image_attributes

    before_validation :guid

    validates :original_url, presence: true

    validates :format, inclusion: { in: ['jpeg', 'png', 'gif', nil] }

    enum status: [ :started, :created, :processing, :complete, :error, :retrying, :cancelled ]

    before_validation :initialize_attributes, on: :create
  end

  # need to implement these for your image classes
  def destination_path
  end

  def published_url
  end

  def initialize_attributes
    self.status ||= :created
    guid
    url
  end

  def guid
    self[:guid] ||= SecureRandom.uuid
    self[:guid]
  end

  def copy_media(force = false)
    if !task || force
      Tasks::CopyImageTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def url
    complete? ? self[:url] : self[:original_url]
  end

  def original_url=(url)
    super
    if original_url_changed?
      reset_image_attributes
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

  def update_from_fixer(fixer_task)
    update_attributes!(url: published_url)
  end
end
