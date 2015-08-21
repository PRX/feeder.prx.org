class Tasks::DeleteAudioTask < ::Task

  def start!
    self.options = {
      job_type: 'audio',
      source: audio_url(episode, get_story)
    }.with_indifferent_access
    # job = fixer_delete_file(options)
    # self.job_id = job[:job][:id]
    save!
  end

  def audio_url(ep, story)
    dest_path = "#{ep.podcast.path}/#{ep.guid}/#{story.audio[0].filename}"
    "s3://#{feeder_storage_bucket}/#{dest_path}"
  end

  def task_status_changed(fixer_task)
    episode.podcast.publish! if complete?
  end

  def get_story(account = nil)
    api(account).tap { |a| a.href = episode.prx_uri }.get
  end

  def episode
    owner
  end
end
