class FixerCallbackWorker
  include Shoryuken::Worker

  shoryuken_options queue: "#{Rails.configuration.active_job.queue_name_prefix}_feeder_fixer_callback", auto_delete: true

  def perform(sqs_msg, job)
    Task.callback(job)
  end
end
