class MediaResource < ApplicationRecord
  has_one :task, -> { order("id desc") }, as: :owner
  has_many :tasks, as: :owner

  belongs_to :episode, -> { with_deleted }, touch: true, optional: true

  acts_as_paranoid

  enum :status, [:started, :created, :processing, :complete, :error, :retrying, :cancelled, :invalid], prefix: true

  before_validation :initialize_attributes, on: :create

  validates :original_url, presence: true

  validates :medium, inclusion: {in: %w[audio video]}, if: :status_complete?

  after_create :replace_resources!

  scope :complete_or_replaced, -> do
    with_deleted
      .status_complete
      .where("deleted_at IS NULL OR replaced_at IS NOT NULL")
      .order("created_at DESC")
  end

  def self.build(file, position = nil)
    media =
      if file&.is_a?(Hash)
        new(file)
      elsif file&.is_a?(String)
        new(original_url: file)
      else
        file
      end

    media.try(:position=, position)

    media.try(:original_url).try(:present?) ? media : nil
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

  def url
    self[:url] ||= media_url
  end

  def replace_resources!
  end

  def href
    status_complete? ? url : original_url
  end

  def href=(h)
    if original_url != h
      self.original_url = h
      self.task = nil
      self.status = nil
    end
    original_url
  end

  def file_name
    if original_url.present?
      uri = URI.parse(original_url)
      File.basename(uri.path)
    end
  end

  def copy_media(force = false)
    if !task || force
      Tasks::CopyMediaTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def media_url
    media_url_for_base(episode.base_published_url) if episode
  end

  def media_url_for_base(base_published_url)
    ext = File.extname(original_url || "")
    ext = ".mp3" if ext.blank?
    "#{base_published_url}/#{guid}#{ext}"
  end

  def replace?(res)
    original_url != res.try(:original_url)
  end

  def update_resource(res)
    # NOTE: media_resources have no user settable fields
  end

  def retryable?
    status_processing? && (Time.now - updated_at) > 30
  end

  def retry!
    status_retrying!
    copy_media(true)
  end

  def _retry=(_val)
    retry!
  end
end
