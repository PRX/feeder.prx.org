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
    task.result[:JobResult][:Result][1][:Inspection][:Audio][:Bitrate] = '999000'

    task.update_attributes(status: 'created')
    task.media_resource.bit_rate.wont_equal 999

    task.update_attributes(status: 'complete')
    task.media_resource.bit_rate.must_equal 999
  end

  it 'does not throw errors when owner is missing on callback' do
    task.owner = nil
    task.update_attributes(status: 'complete')
  end
end
