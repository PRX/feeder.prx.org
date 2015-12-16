require 'test_helper'

describe Tasks::CopyAudioTask do
  let(:task) { create(:copy_audio_task) }

  let(:msg) { json_file(:prx_story_small) }

  let(:audio_msg) { json_file(:prx_story_with_audio) }

  let(:story) do
    body = JSON.parse(msg)
    href = body['_links']['self']['href']
    resource = task.api
    link = HyperResource::Link.new(resource, href: href)
    HyperResource.new_from(body: body, resource: resource, link: link)
  end

  before do
    if use_webmock?
      stub_request(:get, "https://cms.prx.org/api/v1/stories/80548").
        to_return(status: 200, body: msg, headers: {})

      stub_request(:get, "https://cms.prx.org/api/v1/stories/80548/audio_files").
        to_return(status: 200, body: audio_msg, headers: {})

      stub_request(:get, "https://cms.prx.org/api/v1/audio_files/406322/original?expiration=604800").
        to_return(status: 301, body: '', headers: { location: 'http://final/location.mp3' } )
    end
  end

  it 'can start the job' do
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      task.stub(:get_account_token, "token") do
        task.start!
        task.options[:source].must_equal 'http://final/location.mp3'
        task.options[:destination].must_match /s3:\/\/test-prx-feed\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/
        task.options[:audio_uri].must_equal '/api/v1/audio_files/406322'
      end
    end
  end

  it 'alias owner as episode' do
    task.episode.must_equal task.owner.episode
  end

  it 'knows what bucket to drop the file in' do
    task.feeder_storage_bucket.must_equal 'test-prx-feed'
  end

  it 'determines a destination url' do
    podcast = Minitest::Mock.new.expect(:path, 'path')
    episode = Minitest::Mock.new
    episode.expect(:podcast, podcast)
    episode.expect(:guid, 'guid')
    episode.expect(:url, 'http://test-f.prxu.org/path/guid/audio.mp3')
    url = task.destination_url(episode)
    url.must_equal 's3://test-prx-feed/path/guid/audio.mp3?x-fixer-public=true'
  end

  it 'determines the story audio uri' do
    task.story_audio_uri(story).must_equal '/api/v1/audio_files/406322'
  end

  it 'can publish on complete' do
    podcast = Minitest::Mock.new
    podcast.expect(:publish!, true)
    podcast.expect(:path, 'path')

    episode = Minitest::Mock.new
    episode.expect(:podcast, podcast)
    episode.expect(:podcast, podcast)
    episode.expect(:prx_uri, '/api/v1/stories/80548')
    episode.expect(:guid, 'guid')
    episode.expect(:url, 'http://test-f.prxu.org/path/guid/audio.mp3')

    task.stub(:episode, episode) do
      HighwindsAPI::Content.stub(:purge_url, true) do
        task.task_status_changed({}, 'complete')
      end
    end
  end

  it 'can detect if the audio file has changed' do
    task.options = {}
    assert task.new_audio_file?(story)
  end

  it 'does not throw errors when owner is missing on callback' do
    task.owner = nil
    task.task_status_changed({}, 'complete')
  end
end
