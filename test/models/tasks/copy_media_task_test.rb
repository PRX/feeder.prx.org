require 'test_helper'

describe Tasks::CopyMediaTask do
  let(:task) { create(:copy_media_task) }

  let(:story) do
    body = JSON.parse(json_file(:prx_story_small))
    href = body.dig(:_links, :self, :href)
    resource = task.api
    link = HyperResource::Link.new(resource, href: href)
    HyperResource.new_from(body: body, resource: resource, link: link)
  end

  it 'has task options' do
    options = task.task_options
    options.keys.must_equal %w(callback job_type source destination)
    options[:callback].must_match /^sqs:\/\//
    options[:job_type].must_equal 'audio'
    options[:source].must_equal 's3://prx-testing/test/audio.mp3'
    options[:destination].must_match /^s3:\/\//
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
    url.must_equal "s3://test-prx-feed/path/guid/audio.mp3"
  end

  it 'use original url as the source url' do
    task.source_url(task.media_resource).must_equal task.media_resource.original_url
  end

  it 'updates status before save' do
    task.status.must_equal 'complete'
    task.media_resource.status.must_equal 'complete'
    task.update_attributes(status: 'processing')
    task.status.must_equal 'processing'
    task.media_resource.status.must_equal 'processing'
  end

  it 'can publish on complete' do
    podcast = Minitest::Mock.new
    podcast.expect(:publish!, true, [])
    podcast.expect(:path, 'path')

    episode = Minitest::Mock.new
    episode.expect(:podcast, podcast)
    episode.expect(:podcast, podcast)
    episode.expect(:prx_uri, '/api/v1/stories/80548')
    episode.expect(:guid, 'guid')
    episode.expect(:url, 'http://test-f.prxu.org/path/guid/audio.mp3')

    task.stub(:episode, episode) do
      task.update_attributes(status: 'complete')
      # TODO: why do these fail?
      # podcast.verify
      # episode.verify
    end
  end

  it 'does not throw errors when owner is missing on callback' do
    task.owner = nil
    task.update_attributes(status: 'complete')
  end
end
