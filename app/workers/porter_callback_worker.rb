class PorterCallbackWorker < ApplicationWorker
  shoryuken_options queue: prefix_name("fixer_callback"), auto_delete: true

  def perform(_sqs_msg, job)
    Task.callback(job)
  end
end
