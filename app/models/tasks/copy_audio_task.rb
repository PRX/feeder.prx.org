class Tasks::CopyAudioTask < ::Task

  def start!
    self.options = task_options
    job = fixer_copy_file(options)
    self.job_id = job[:job][:id]
    save!
  end

  # callback - example result info:
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
  def task_status_changed(fixer_task)
    url = "http://#{feeder_cdn_host}/#{audio_path(episode)}"
    HighwindsAPI::Content.purge_url(url, false)

    episode.podcast.publish! if complete?
  end

  def task_options
    {
      job_type: 'audio',
      destination: destination_url(episode),
    }.merge(story_options || episode_options).with_indifferent_access
  end

  def story_options
    return nil unless episode.prx_uri
    account_uri = get_story.account.href
    story = get_story(account_uri)
    {
      source: original_url(story),
      audio_uri: story_audio_uri(story)
    }
  end

  def episode_options
    audio_uri = episode.overrides[:audio][:url]
    {
      source: audio_uri,
      audio_uri: audio_uri
    }
  end

  def audio_info
    result[:task][:result_details][:info]
  end

  def new_audio_file?(story = nil)
    story ||= get_story
    options[:audio_uri] != story_audio_uri(story)
  end

  def story_audio_uri(story)
    story.audio[0].body['_links']['self']['href']
  end

  def get_story(account = nil)
    api(account: account).tap { |a| a.href = episode.prx_uri }.get
  end

  def original_url(story)
    resp = story.audio[0].original(expiration: 1.week.to_i).get_response
    resp.headers['location']
  end

  def destination_url(ep)
    URI::Generic.build(
      scheme: 's3',
      host: feeder_storage_bucket,
      path: "/" + audio_path(ep),
      query: "x-fixer-public=true"
    ).to_s
  end

  def audio_path(ep)
    "#{ep.podcast.path}/#{ep.guid}/audio.mp3"
  end

  def episode
    owner
  end
end
