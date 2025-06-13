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

    validates :format, inclusion: {in: %w[jpeg png gif]}, if: :status_complete?

    enum :status, [:started, :created, :processing, :complete, :error, :retrying, :cancelled, :invalid], prefix: true

    scope :complete_or_replaced, -> do
      with_deleted
        .status_complete
        .where("#{table_name}.deleted_at IS NULL OR #{table_name}.replaced_at IS NOT NULL")
        .order("created_at DESC")
    end

    after_create :replace_resources!
    after_save :publish!
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
    if original_url.present?
      File.basename(URI.parse(original_url).path)
    end
  end

  def copy_media(force = false)
    if force || !(status_complete? || task)
      Tasks::CopyImageTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def url
    self[:url] ||= published_url
  end

  def path
    URI.parse(url).path.sub(/\A\//, "") if url.present?
  end

  def href
    (status_complete? || status_invalid?) ? url : original_url
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

  # only replace if there is a new image url, different from current
  def replace?(img)
    original_url && (original_url != img.try(:original_url))
  end

  def update_image(img)
    %i[alt_text caption credit].each do |key|
      img[key] = self[key]
    end
  end

  def retryable?
    if %w[started created processing retrying].include?(status)
      last_event = task&.updated_at || updated_at || Time.now
      Time.now - last_event > 100
    else
      status_error?
    end
  end

  def retry!
    if retryable?
      status_retrying!
      copy_media(true)
    end
  end

  def _retry=(_val)
    retry!
  end
end
