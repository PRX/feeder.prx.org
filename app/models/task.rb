require "hash_serializer"
require "prx/api"

class Task < ApplicationRecord
  include PorterCallback
  include PorterUtils

  enum :status, [:started, :created, :processing, :complete, :error, :retrying, :cancelled]

  serialize :options, coder: HashSerializer
  def options
    self[:options] ||= {}
  end

  serialize :result, coder: HashSerializer
  def result
    self[:result] ||= {}
  end

  belongs_to :owner, polymorphic: true, optional: true

  before_validation { self.status ||= :started }

  scope :analyze_media, -> { where(type: "Tasks::AnalyzeMediaTask") }
  scope :copy_media, -> { where(type: "Tasks::CopyMediaTask") }
  scope :copy_image, -> { where(type: "Tasks::CopyImageTask") }
  scope :copy_transcript, -> { where(type: "Tasks::CopyTranscript") }
  scope :fix_media, -> { where(type: "Tasks::FixMediaTask") }
  scope :record_stream, -> { where(type: "Tasks::RecordStreamTask") }
  scope :bad_audio_duration, -> { where("result ~ '\"DurationDiscrepancy\":([5-9]\\d[1-9]|[6-9]\\d{2}|[1-9]\d{3})'") }
  scope :bad_audio_bytes, -> { where("result ~ '\"UnidentifiedBytes\":[1-9]'") }
  scope :bad_audio_vbr, -> { where("result ~ '\"VariableBitrate\":true'") }

  def self.callback(msg)
    job_id = porter_callback_job_id(msg)
    task = lookup_task(job_id)

    task&.with_lock do
      status = porter_callback_status(msg)
      time = porter_callback_time(msg)

      if status && time && (task.logged_at.nil? || (time >= task.logged_at))
        task.update!(status: status, logged_at: time, result: msg)
      end
    end
  end

  def self.lookup_task(job_id)
    if job_id
      task = order(id: :desc).find_by_job_id(job_id) || Tasks::RecordStreamTask.from_job_id(job_id)
      unless task
        Rails.logger.error("Unrecognized Task job id", job_id: job_id)
        NewRelic::Agent.notice_error(StandardError.new("Unrecognized Task job id: #{job_id}"))
      end
      task
    end
  end

  def job_id
    self[:job_id] ||= SecureRandom.uuid
  end

  def source_url
  end

  def bad_audio?
    bad_audio_duration? || bad_audio_bytes? || bad_audio_vbr?
  end

  def bad_audio_duration?
    porter_callback_inspect.dig(:Audio, :DurationDiscrepancy).to_i > 500
  end

  def bad_audio_bytes?
    porter_callback_inspect.dig(:Audio, :UnidentifiedBytes).to_i > 0
  end

  def bad_audio_vbr?
    !!porter_callback_inspect.dig(:Audio, :VariableBitrate)
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
