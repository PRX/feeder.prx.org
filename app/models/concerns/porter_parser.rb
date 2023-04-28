require "active_support/concern"

module PorterParser
  extend ActiveSupport::Concern

  class_methods do
    def porter_callback_job_id(msg)
      porter_parsed(msg).try(:[], :Job).try(:[], :Id)
    end

    def porter_callback_status(msg)
      key = porter_key(msg).to_s
      if key == "JobReceived"
        "processing"
      elsif key == "JobResult" && porter_failed(msg).any?
        "error"
      elsif key == "JobResult" && porter_parsed(msg)[:State] != "DONE"
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
      porter_parsed(msg).try(:[], :Result)
    end

    def porter_callback_copy(msg)
      porter_result(msg, "Copy")
    end

    def porter_callback_inspect(msg)
      porter_result(msg, "Inspect")
    end

    protected

    def porter_result(msg, task = nil)
      results = porter_parsed(msg).try(:[], :TaskResults) || []
      task ? results.detect { |t| t[:Task] == task } : results
    end

    def porter_failed(msg, type = nil)
      failed = porter_parsed(msg).try(:[], :FailedTasks) || []
      type ? failed.detect { |t| t[:Type] == type } : failed
    end

    def porter_parsed(msg)
      msg[porter_key(msg)].with_indifferent_access if porter_key(msg)
    end

    def porter_key(msg)
      (msg.try(:keys) || []).find do |key|
        %w[JobReceived TaskResult JobResult].include?(key.to_s)
      end
    end
  end

  def porter_callback_media_meta
    info = self.class.porter_callback_inspect(result).try(:[], :Inspection)
    mime = porter_callback_mime(info)
    meta = {
      mime_type: mime,
      medium: (mime || "").split("/").first,
      file_size: porter_callback_size(info)
    }
    audio_meta = porter_callback_audio_meta(mime, info)
    video_meta = porter_callback_video_meta(mime, info)

    meta.merge(audio_meta).merge(video_meta)
  end

  def porter_callback_image_meta
    info = self.class.porter_callback_inspect(result).try(:[], :Inspection)
    mime = porter_callback_mime(info)
    meta = {
      size: porter_callback_size(info)
    }

    # only return for actual images - not detected images in id3 tags
    if info && info[:Image] && mime.starts_with?("image/")
      meta.merge(
        format: info[:Image][:Format],
        height: info[:Image][:Height].to_i,
        size: info[:Size].to_i,
        width: info[:Image][:Width].to_i
      )
    else
      meta
    end
  end

  def porter_callback_mime(info)
    if info && info[:MIME]
      info[:MIME]
    elsif info && info[:Audio]
      "audio/mpeg"
    end
  end

  def porter_callback_size(info)
    info[:Size].to_i if info
  end

  def porter_callback_audio_meta(mime, info)
    if info && info[:Audio]
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

  def porter_callback_video_meta(mime, info)
    # only return for actual videos - not detected images in id3 tags
    if info && info[:Video] && mime.starts_with?("video")
      {
        duration: info[:Video][:Duration].to_f / 1000,
        bit_rate: info[:Video][:Bitrate].to_i / 1000,
        frame_rate: porter_callback_video_framerate(info[:Video][:Framerate]),
        width: info[:Video][:Width].to_i,
        height: info[:Video][:Height].to_i
      }
    else
      {}
    end
  end

  # note: frame_rate is an integer in the schema, so just round it
  def porter_callback_video_framerate(fraction_str)
    Rational(fraction_str).to_f.round
  rescue
    nil
  end
end
