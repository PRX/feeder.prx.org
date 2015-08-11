class Tasks::CopyAudioTask < ::Task

  def start!
    account_uri = get_story.account.href
    story = get_story(account_uri)

    self.options = {
      job_type: 'audio',
      source: original_url(story),
      destination: destination_url(episode, story),
      audio_uri: story_audio_uri(story)
    }.with_indifferent_access
    job = fixer_copy_file(options)
    self.job_id = job[:job][:id]
    save!
  end

  # example result info:
  # {
  #   :size=>774059,
  #   :content_type=>"audio/mpeg",
  #   :format=>"mp3",
  #   :channel_mode=>"Mono",
  #   :channels=>1,
  #   :bit_rate=>128,
  #   :length=>48.352653,
  #   :sample_rate=>44100
  # }
  def audio_info
    result[:task][:result_details][:info]
  end

  def task_status_changed(fixer_task)
    url = "http://#{feeder_cdn_host}/#{audio_path(episode, get_story)}"
    HighwindsAPI::Content.purge_url(url, false)

    episode.podcast.publish! if complete?
  end

  def new_audio_file?(story = nil)
    story ||= get_story
    options[:prx_audio_uri] != story_audio_uri(story)
  end

  def story_audio_uri(story)
    story.audio[0].body['_links']['self']['href']
  end

  def get_story(account = nil)
    api(account).tap { |a| a.href = episode.prx_uri }.get
  end

  def original_url(story)
    resp = story.audio[0].original(expiration: 1.week.to_i).get_response
    resp.headers['location']
  end

  def destination_url(ep, story)
    "s3://#{feeder_storage_bucket}/#{audio_path(ep, story)}?x-fixer-public=true"
  end

  def audio_path(ep, story)
    "#{ep.podcast.path}/#{ep.guid}/#{story.audio[0].filename}"
  end

  def episode
    owner
  end
end
