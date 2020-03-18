require 'active_support/concern'

module FixerParser
  extend ActiveSupport::Concern

  class_methods do
    def fixer_callback_job_id(msg)
      fixer_task(msg).try(:[], :job).try(:[], :id)
    end

    def fixer_callback_status(msg)
      fixer_result(msg).try(:[], :status)
    end

    def fixer_callback_time(msg)
      logged_at = fixer_result(msg).try(:[], :logged_at)
      Time.parse(logged_at) if logged_at
    end

    def fixer_callback_info(msg)
      fixer_result(msg).try(:[], :info)
    end

    protected

    def fixer_task(msg)
      msg.try(:with_indifferent_access).try(:[], :task)
    end

    def fixer_result(msg)
      fixer_task(msg).try(:[], :result_details)
    end
  end

  def fixer_callback_media_meta
    info = self.class.fixer_callback_info(result)
    if info
      mime = fixer_callback_mime(info)
      {
        mime_type: mime,
        medium: mime.split('/').first,
        file_size: info[:size].to_i,
        sample_rate: info[:sample_rate].to_i,
        channels: info[:channels].to_i,
        duration: info[:length].to_f,
        bit_rate: info[:bit_rate].to_i,
      }
    end
  end

  def fixer_callback_mime(info)
    content_type = info.with_indifferent_access[:content_type]
    if content_type.blank? || content_type == 'application/octet-stream'
      'audio/mpeg'
    else
      content_type
    end
  end
end
