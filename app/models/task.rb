require "hash_serializer"
require "prx_access"

class Task < ApplicationRecord
  include PorterCallback
  include PorterUtils

  enum status: [:started, :created, :processing, :complete, :error, :retrying, :cancelled]

  serialize :options, HashSerializer
  def options
    self[:options] ||= {}
  end

  serialize :result, HashSerializer
  def result
    self[:result] ||= {}
  end

  belongs_to :owner, polymorphic: true, optional: true

  before_validation { self.status ||= :started }

  scope :copy_media, -> { where(type: "Tasks::CopyMediaTask") }
  scope :copy_image, -> { where(type: "Tasks::CopyImageTask") }
  scope :bad_audio_duration, -> { where("result ~ '\"DurationDiscrepancy\":([5-9]\\d[1-9]|[6-9]\\d{2}|[1-9]\d{3})'") }
  scope :bad_audio_bytes, -> { where("result ~ '\"UnidentifiedBytes\":[1-9]'") }

  def self.callback(msg)
    Task.transaction do
      if (job_id = porter_callback_job_id(msg))
        status = porter_callback_status(msg)
        time = porter_callback_time(msg)
      end

      task = where(job_id: job_id).lock(true).first
      if task && status && time && (task.logged_at.nil? || (time >= task.logged_at))
        task.update!(status: status, logged_at: time, result: msg)
      end
    end
  end

  def job_id
    self[:job_id] ||= SecureRandom.uuid
  end

  def source_url
  end

  def bad_audio_duration?
    porter_callback_inspect.dig(:Audio, :DurationDiscrepancy).to_i > 500
  end

  def bad_audio_bytes?
    porter_callback_inspect.dig(:Audio, :UnidentifiedBytes).to_i > 0
  end

  def start!
    self.status = "started"
    self.options = {
      Id: job_id,
      Source: porter_source,
      Tasks: porter_tasks,
      Callbacks: porter_callbacks
    }

    porter_start!(options)
    save!
  end
end
