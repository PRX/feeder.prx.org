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

    def rexif_callback_copy(msg)
      rexif_result(msg, 'Copy')
    end

    def rexif_callback_inspect(msg)
      rexif_result(msg, 'Inspect')
    end

    protected

    def rexif_result(msg, task)
      results = rexif_parsed(msg).try(:[], :Result) || []
      results.detect {|t| t[:Task] == task}
    end

    def rexif_parsed(msg)
      msg[rexif_key(msg)].with_indifferent_access if rexif_key(msg)
    end

    def rexif_key(msg)
      (msg.try(:keys) || []).find do |key|
        %w(JobReceived TaskResult JobResult).include?(key.to_s)
      end
    end
  end

  def rexif_callback_media_meta
    info = self.class.rexif_callback_inspect(result).try(:[], :Inspection)
    if info
      mime = rexif_callback_mime(info)
      meta = {
        mime_type: mime,
        medium: (mime || '').split('/').first,
        file_size: info[:Size].to_i
      }
      audio_meta = rexif_callback_audio_meta(mime, info)
      video_meta = rexif_callback_video_meta(mime, info)

      meta.merge(audio_meta).merge(video_meta)
    end
  end

  def rexif_callback_mime(info)
    if info[:MIME]
      info[:MIME]
    elsif info[:Audio]
      'audio/mpeg'
    else
      nil
    end
  end

  def rexif_callback_audio_meta(mime, info)
    if info[:Audio]
      {
        sample_rate: info[:Audio][:Frequency].to_i,
        channels: info[:Audio][:Channels].to_i,
        duration: info[:Audio][:Duration].to_f / 1000,
        bit_rate: info[:Audio][:Bitrate].to_i / 1000
      }
    else
      {}
    end
  end

  def rexif_callback_video_meta(mime, info)
    # only return for actual videos - not detected images in id3 tags
    if info[:Video] && mime.starts_with?('video')
      {
        duration: info[:Video][:Duration].to_f / 1000,
        bit_rate: info[:Video][:Bitrate].to_i / 1000,
        frame_rate: info[:Video][:Framerate],
        width: info[:Video][:Width].to_i,
        height: info[:Video][:Height].to_i
      }
    else
      {}
    end
  end
end
