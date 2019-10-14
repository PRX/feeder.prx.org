require 'hash_serializer'
require 'prx_access'

class Task < BaseModel
  include PRXAccess
  include FixerParser
  include FixerEncoder

  enum status: [ :started, :created, :processing, :complete, :error, :retrying, :cancelled ]

  serialize :options, HashSerializer
  def options
    self[:options] ||= {}
  end

  serialize :result, HashSerializer
  def result
    self[:result] ||= {}
  end

  belongs_to :owner, polymorphic: true

  before_validation { self.status ||= :started }

  scope :copy_media, -> { where(type: 'Tasks::CopyMediaTask') }
  scope :copy_image, -> { where(type: 'Tasks::CopyImageTask') }

  def self.callback(msg)
    Task.transaction do
      job_id = fixer_callback_job_id(msg) || rexif_callback_job_id(msg)
      status = fixer_callback_status(msg) || rexif_callback_status(msg)
      time = fixer_callback_time(msg) || rexif_callback_time(msg)
      task = where(job_id: job_id).lock(true).first
      if task && (task.logged_at.nil? || (time >= task.logged_at))
        task.update_attributes!(status: status, logged_at: time, result: msg)
      end
    end
  end

  def start!
    self.options = task_options
    if rexif_enabled?
      self.job_id = rexif_start!(options)
    else
      self.job_id = fixer_start!(options)
    end
    save!
  end

  def task_options
    {callback: callback_queue}.with_indifferent_access
  end

  def feeder_storage_bucket
    ENV['FEEDER_STORAGE_BUCKET']
  end

  def callback_queue
    q = ENV['FIXER_CALLBACK_QUEUE'] || "#{ENV['RAILS_ENV']}_feeder_fixer_callback"
    "sqs://#{ENV['AWS_REGION']}/#{q}"
  end

  def rexif_enabled?
    false
  end
end
