module SegmenterHelper
  def segmenter_status_class(uncut)
    if uncut&.status_complete?
      "success"
    elsif uncut.nil? || upload_processing?(uncut)
      "primary"
    else
      "danger"
    end
  end

  def segmenter_status_msg(episode, uncut)
    url = edit_episode_path(episode, anchor: "episode-media")

    if uncut.nil?
      t(".missing_html", url: url)
    elsif upload_processing?(uncut)
      t(".processing_html", url: url)
    else
      t(".error_html", url: url)
    end
  end
end
