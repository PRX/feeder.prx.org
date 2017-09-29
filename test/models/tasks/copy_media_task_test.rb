require 'test_helper'

describe Tasks::CopyMediaTask do
  let(:task) { create(:copy_media_task) }

  let(:audio_msg) { json_file(:prx_story_with_audio) }

  let(:story) do
    body = JSON.parse(json_file(:prx_story_small))
    href = body.dig(:_links, :self, :href)
    resource = task.api
    link = HyperResource::Link.new(resource, href: href)
    HyperResource.new_from(body: body, resource: resource, link: link)
  end

  it 'can start the job' do
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      task.stub(:get_account_token, "token") do
        task.start!
        task.options[:source].must_equal task.media_resource.original_url
        task.options[:destination].must_match /s3:\/\/test-prx-feed\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/
      end
    end
  end

  it 'remove query string from audio url' do
    task.media_resource.wont_be_nil
    original = task.media_resource.original_url
    task.media_resource.original_url = original + '?remove=this'
    task.task_options[:source].must_equal original
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

  it 'use original url as the source url' do
    task.source_url(task.media_resource).must_equal task.media_resource.original_url
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

  it 'does not throw errors when owner is missing on callback' do
    task.owner = nil
    task.task_status_changed({}, 'complete')
  end
end
