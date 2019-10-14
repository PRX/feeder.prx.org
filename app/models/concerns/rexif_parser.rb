require 'active_support/concern'

module RexifParser
  extend ActiveSupport::Concern

  class_methods do
    def rexif_callback_job_id(msg)
      rexif_parsed(msg).try(:[], :Job).try(:[], :Id)
    end

    def rexif_callback_status(msg)
      key = rexif_key(msg).to_s
      if key == 'JobReceived'
        'processing'
      elsif key == 'JobResult' && rexif_parsed(msg)[:Error]
        'error'
      elsif key == 'JobResult'
        'complete'
      end
    end

    def rexif_callback_time(msg)
      logged_at = msg.try(:with_indifferent_access).try(:[], :Time)
      Time.parse(logged_at) if logged_at
    end

    def rexif_callback_results(msg)
      rexif_parsed(msg).try(:[], :Result)
    end

    protected

    def rexif_parsed(msg)
      msg[rexif_key(msg)].with_indifferent_access if rexif_key(msg)
    end

    def rexif_key(msg)
      (msg.try(:keys) || []).find do |key|
        %w(JobReceived TaskResult JobResult).include?(key.to_s)
      end
    end
  end
end
