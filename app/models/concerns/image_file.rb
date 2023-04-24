require "newrelic_rpm"
require "active_support/concern"

module ImageFile
  extend ActiveSupport::Concern

  included do
    has_one :task, -> { order("id desc") }, as: :owner
    has_many :tasks, as: :owner

    acts_as_paranoid

    before_validation :initialize_attributes, on: :create

    validates :original_url, presence: true

    validates :format, inclusion: {in: ["jpeg", "png", "gif", nil]}

    enum :status, [:started, :created, :processing, :complete, :error, :retrying, :cancelled], prefix: true

    scope :complete_or_replaced, -> do
      with_deleted
        .status_complete
        .where("deleted_at IS NULL OR replaced_at IS NOT NULL")
        .order("created_at DESC")
    end

    after_create :replace_resources!
  end

  class_methods do
    def build(file)
      img =
        if file&.is_a?(Hash)
          new(file)
        elsif file&.is_a?(String)
          new(original_url: file)
        else
          file
        end

      img.try(:original_url).try(:present?) ? img : nil
    end
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

  def file_name
    File.basename(URI.parse(original_url).path)
  end

  def copy_media(force = false)
    if !task || force
      Tasks::CopyImageTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def url
    status_complete? ? self[:url] : self[:original_url]
  end

  def href
    status_complete? ? url : original_url
  end

  def href=(h)
    if original_url != h
      self.original_url = h
    end
    original_url
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
    self.status = :created
  end

  def replace?(img)
    original_url != img.try(:original_url)
  end

  def update_image(img)
    %i[alt_text caption credit].each do |key|
      img[key] = self[key]
    end
  end
end
