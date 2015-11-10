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
  def task_status_changed(fixer_task, new_status)
    media_resource.update_attribute(:status, new_status)
    audio_info = fixer_task.fetch(:task, {}).fetch(:result_details, {}).fetch(:info, nil)
    if new_status == 'complete' && audio_info
      self.mime_type = audio_info[:content_type]
      self.file_size = audio_info[:size].to_i
      self.medium = self.mime_type.split('/').first
      self.sample_rate = audio_info[:sample_rate].to_i
      self.channels = audio_info[:channels].to_i
      self.duration = audio_info[:length].to_f
      self.bit_rate = audio_info[:bit_rate].to_i
    end

    HighwindsAPI::Content.purge_url(episode.url, false)
    episode.podcast.publish! if complete?
  end

  def task_options
    {
      job_type: 'audio',
      destination: destination_url(media_resource),
    }.merge(episode_options || story_options).with_indifferent_access
  end

  def episode_options
    return nil if episode && episode.prx_uri
    {
      source: media_resource.original_url,
      audio_uri: media_resource.original_url
    }
  end

  def story_options
    account_uri = get_story.account.href
    story = get_story(account_uri)
    {
      source: original_url(story),
      audio_uri: story_audio_uri(story)
    }
  end

  def new_audio_file?(story = nil)
    options[:audio_uri] != (media_resource.original_url || story_audio_uri(story))
  end

  def story_audio_uri(story = nil)
    story ||= get_story
    story.audio[0].body['_links']['self']['href']
  end

  def get_story(account = nil)
    api(account: account).tap { |a| a.href = episode.prx_uri }.get
  end

  def original_url(story)
    resp = story.audio[0].original(expiration: 1.week.to_i).get_response
    resp.headers['location']
  end

  def destination_url(media_resource)
    URI::Generic.build(
      scheme: 's3',
      host: feeder_storage_bucket,
      path: audio_path(media_resource),
      query: "x-fixer-public=true"
    ).to_s
  end

  def audio_path(media_resource)
    URI.parse(media_resource.url).path
  end

  def episode
    media_resource.episode
  end

  def media_resource
    owner
  end
end
