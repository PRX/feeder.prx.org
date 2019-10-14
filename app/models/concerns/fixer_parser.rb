require 'active_support/concern'

module FixerParser
  extend ActiveSupport::Concern

  class_methods do
    def fixer_callback_job_id(msg)
      msg.try(:[], 'task').try(:[], 'job').try(:[], 'id')
    end

    def fixer_callback_status(msg)
      fixer_result(msg).try(:[], 'status')
    end

    def fixer_callback_time(msg)
      logged_at = fixer_result(msg).try(:[], 'logged_at')
      Time.parse(logged_at) if logged_at
    end

    def fixer_callback_info(msg)
      fixer_result(msg).try(:[], 'info')
    end

    def fixer_result(msg)
      msg.try(:[], 'task').try(:[], 'result_details')
    end
  end

  def fixer_callback_audio_meta
    info = self.class.fixer_callback_info(result)
    mime = fixer_callback_mime(info)
    {
      mime_type: mime,
      medium: mime.split('/').first,
      file_size: info['size'].to_i,
      sample_rate: info['sample_rate'].to_i,
      channels: info['channels'].to_i,
      duration: info['length'].to_f,
      bit_rate: info['bit_rate'].to_i,
    }
  end

  def fixer_callback_mime(info)
    if info['content_type'].nil? || info['content_type'] == 'application/octect-stream'
      'audio/mpeg'
    else
      info['content_type']
    end
  end
end
