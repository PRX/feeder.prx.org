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
    assert_equal options.keys, %w(callback job_type source destination)
    assert_match(/^sqs:\/\//, options[:callback])
    assert_equal options[:job_type], 'audio'
    assert_equal options[:source], 's3://prx-testing/test/audio.mp3'
    assert_match(/^s3:\/\//, options[:destination])
  end

  it 'remove query string from audio url' do
    refute_nil task.media_resource
    original = task.media_resource.original_url
    task.media_resource.original_url = original + '?remove=this'
    assert_equal task.task_options[:source], original
  end

  it 'alias owner as episode' do
    assert_equal task.episode, task.owner.episode
  end

  it 'knows what bucket to drop the file in' do
    assert_equal task.feeder_storage_bucket, 'test-prx-feed'
  end

  it 'determines a destination url' do
    podcast = Minitest::Mock.new.expect(:path, 'path')
    episode = Minitest::Mock.new
    episode.expect(:podcast, podcast)
    episode.expect(:guid, 'guid')
    episode.expect(:url, 'http://test-f.prxu.org/path/guid/audio.mp3')
    url = task.destination_url(episode)
    assert_equal url, "s3://test-prx-feed/path/guid/audio.mp3"
  end

  it 'use original url as the source url' do
    assert_equal task.source_url(task.media_resource), task.media_resource.original_url
  end

  it 'updates status before save' do
    assert_equal task.status, 'complete'
    assert_equal task.media_resource.status, 'complete'
    task.update_attributes(status: 'processing')
    assert_equal task.status, 'processing'
    assert_equal task.media_resource.status, 'processing'
  end

  it 'replaces resources and publishes on complete' do
    replace = MiniTest::Mock.new
    publish = MiniTest::Mock.new

    task.media_resource.stub(:replace_resources!, replace) do
      task.episode.podcast.stub(:publish!, publish) do
        task.update_attributes(status: 'created')
        replace.verify
        publish.verify

        replace.expect(:call, nil)
        publish.expect(:call, nil)
        task.update_attributes(status: 'complete')
        replace.verify
        publish.verify
      end
    end
  end

  it 'updates audio metadata on complete' do
    task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:Bitrate] = '999000'

    task.update_attributes(status: 'created')
    refute_equal task.media_resource.bit_rate, 999

    task.update_attributes(status: 'complete')
    assert_equal task.media_resource.bit_rate, 999
  end

  it 'does not throw errors when owner is missing on callback' do
    task.owner = nil
    task.update_attributes(status: 'complete')
  end
end
