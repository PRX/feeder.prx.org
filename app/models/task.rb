require 'hash_serializer'
require 'prx_access'

class Task < BaseModel
  include PRXAccess

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

  # convenient scopes for subclass types
  [:copy_media, :copy_image, :publish_feed, :copy_url].each do |subclass|
    classname = "Tasks::#{subclass.to_s.camelize}Task"
    scope subclass, -> { where('type = ?', classname) }
  end

  # abstract, called by `fixer_callback`
  def task_status_changed(fixer_task, new_status)
  end

  def self.fixer_callback(fixer_task)
    Task.transaction do
      job_id = fixer_task['task']['job']['id']
      task = where(job_id: job_id).lock(true).first
      task.fixer_callback(fixer_task) if task
    end
  end

  def fixer_callback(fixer_task)
    ft = fixer_task['task']
    new_status = ft['result_details']['status']
    new_logged_at = Time.parse(ft['result_details']['logged_at'])
    if logged_at.nil? || (new_logged_at >= logged_at)
      update_attributes!(
        status: new_status,
        logged_at: new_logged_at,
        result: fixer_task
      )
      task_status_changed(fixer_task, new_status)
    end
  end

  def fixer_copy_file(opts = options)
    opts = (opts || {}).with_indifferent_access
    task = {
      task_type: 'copy',
      result: opts[:destination],
      call_back: fixer_call_back_queue
    }
    job = {
      job_type: opts[:job_type],
      original: opts[:source],
      tasks: [ task ],
      priority: 1,
      retry_delay: 300,
      retry_max: 12
    }
    fixer_sqs_client.create_job(job: job)
  end

  def feeder_storage_bucket
    ENV['FEEDER_STORAGE_BUCKET']
  end

  def fixer_call_back_queue
    q = ENV['FIXER_CALLBACK_QUEUE'] || "#{ENV['RAILS_ENV']}_feeder_fixer_callback"
    "sqs://#{ENV['AWS_REGION']}/#{q}"
  end

  def fixer_sqs_client
    @fixer_sqs_client ||= Task.new_fixer_sqs_client
  end

  def fixer_sqs_client=(client)
    @fixer_sqs_client = client
  end

  def self.new_fixer_sqs_client
    Fixer::SqsClient.new
  end
end
