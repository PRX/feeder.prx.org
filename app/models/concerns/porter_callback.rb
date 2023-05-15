require "active_support/concern"

module PorterCallback
  extend ActiveSupport::Concern

  class_methods do
    def porter_callback_job_id(msg)
      porter_callback_parsed(msg).try(:[], :Job).try(:[], :Id)
    end

    def porter_callback_status(msg)
      key = porter_callback_key(msg).to_s
      if key == "JobReceived"
        "processing"
      elsif key == "JobResult" && porter_callback_parsed(msg).try(:[], :FailedTasks).any?
        "error"
      elsif key == "JobResult" && porter_callback_parsed(msg)[:State] != "DONE"
        "error"
      elsif key == "JobResult"
        "complete"
      end
    end

    def porter_callback_time(msg)
      logged_at = msg.try(:with_indifferent_access).try(:[], :Time)
      Time.parse(logged_at) if logged_at
    end

    def porter_callback_results(msg)
      porter_callback_parsed(msg).try(:[], :Result)
    end

    def porter_callback_parsed(msg)
      msg[porter_callback_key(msg)].with_indifferent_access if porter_callback_key(msg)
    end

    def porter_callback_key(msg)
      (msg.try(:keys) || []).find do |key|
        %w[JobReceived TaskResult JobResult].include?(key.to_s)
      end
    end
  end

  def porter_callback_task_result(task)
    parsed = self.class.porter_callback_parsed(result).try(:[], :TaskResults) || []
    parsed.find { |t| t[:Task].to_s == task.to_s }
  end

  def porter_callback_inspect
    porter_callback_task_result(:Inspect).try(:[], :Inspection) || {}
  end

  def porter_callback_mime
    info = porter_callback_inspect

    if info[:MIME]
      info[:MIME]
    elsif info[:Audio]
      "audio/mpeg"
    end
  end

  def porter_callback_size
    porter_callback_inspect[:Size]&.to_i
  end
end
