class FixerCallbackWorker
  include Shoryuken::Worker

  shoryuken_options queue: ENV['FIXER_CALLBACK_QUEUE_NAME'] || ENV['FIXER_CALLBACK_QUEUE'], auto_delete: true

  def perform(sqs_msg, job)
    Task.callback(job)
  end
end
