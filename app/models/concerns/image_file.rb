require 'newrelic_rpm'
require 'active_support/concern'

module ImageFile
  extend ActiveSupport::Concern

  included do
    has_one :task, -> { order('id desc') }, as: :owner
    has_many :tasks, as: :owner

    before_validation :initialize_attributes, on: :create

    before_validation :detect_image_attributes

    validates :original_url, presence: true

    validates :format, inclusion: { in: ['jpeg', 'png', 'gif', nil] }

    enum status: [ :started, :created, :processing, :complete, :error, :retrying, :cancelled ]
  end

  # need to implement these for your image classes
  def destination_path
  end

  def published_url
  end

  def initialize_attributes
    self.status ||= :created
    guid
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
    info = nil
    begin
      fastimage_options = {
        timeout: 10,
        raise_on_failure: true,
        http_header: { 'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X) PRX Feeder/1.0' }
      }
      info = FastImage.new(original_url, fastimage_options)
    rescue FastImage::FastImageException => err
      logger.error(err)
      NewRelic::Agent.notice_error(err)
      raise
    end
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
