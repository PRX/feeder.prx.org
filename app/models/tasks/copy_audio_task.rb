require 'prx_access'
require 'fixer_client'

# keeps track of status of tasks to fixer and any other systems
# not responsible for sending or resending, just tracking status
# (maybe change that - other times used this pattern to include biz logic)

class Tasks::CopyAudioTask < ::Task
  include PrxAccess

  def start!
    account_uri = get_story.account.href
    story = get_story(account_uri)

    source = original_url(story)
    destination = destination_url(episode, story)
    audio_uri = story_audio_uri(story)

    self.options = {
      source: source,
      destination: destination,
      audio_uri: audio_uri
    }
    job = fixer_copy_file(options)
    self.job_id = job[:job][:id]
    save!
  end

  def task_status_changed(fixer_task)
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
    dest_path = "#{ep.podcast.path}/#{ep.guid}/#{story.audio[0].filename}"
    "s3://#{bucket}/#{dest_path}"
  end

  def fixer_copy_file(opts = options)
    task = {
      task_type: 'copy',
      result: opts[:destination],
      call_back: ENV['FIXER_CALLBACK_QUEUE']
    }
    job = { original: opts[:source], job_type: 'audio', tasks: [ task ] }
    fixer_sqs_client.create_job(job: job)
  end

  def fixer_sqs_client
    @fixer_sqs_client ||= Fixer::SqsClient.new
  end

  def fixer_sqs_client=(client)
    @fixer_sqs_client = client
  end

  def bucket
    ENV['PODCAST_BUCKET'] ||
      (Rails.env.production? ? '' : (Rails.env + '-')) + 'prx-feeds'
  end

  def episode
    owner
  end
end
