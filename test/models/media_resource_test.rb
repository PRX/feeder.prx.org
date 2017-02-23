require 'test_helper'

describe MediaResource do
  let(:episode) { create(:episode) }
  let(:media_resource) { create(:media_resource) }
  let(:fixer_task) do
    { 'task' => { 'result_details' => { 'info' => {
      'content_type' => 'test/type',
      'size' => 1111,
      'sample_rate' => 44444,
      'channels' => 3,
      'length' => 2222,
      'bit_rate' => 55
    }}}}
  end

  it 'initializes attributes' do
    mr = MediaResource.new(episode: episode)
    mr.validate
    mr.guid.wont_be_nil
    mr.url.wont_be_nil
    mr.status.must_equal 'created'
  end

  it 'answers if it is processed' do
    media_resource.wont_be :complete?
    media_resource.complete!
    media_resource.must_be :complete?
  end

  it 'sets url based on href' do
    mr = MediaResource.new(episode: episode)
    mr.href.must_be_nil
    mr.href = 'http://test.prxu.org/somefile.mp3'
    mr.href.must_equal 'http://test.prxu.org/somefile.mp3'
    mr.original_url.must_equal 'http://test.prxu.org/somefile.mp3'
  end

  it 'resets processing when href changes' do
    mr = MediaResource.new( episode: episode,
                            status: MediaResource.statuses[:completed],
                            original_url: 'http://test.prxu.org/old.mp3'
                          )
    mr.complete!
    mr.task = Task.new

    mr.href = 'http://test.prxu.org/somefile.mp3'
    mr.href.must_equal 'http://test.prxu.org/somefile.mp3'
    mr.original_url.must_equal 'http://test.prxu.org/somefile.mp3'
    mr.wont_be :complete?
    mr.task.must_be_nil
  end

  it 'provides audio url based on guid' do
    media_resource.media_url.must_match /http:\/\/f-test.prxu.org\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/
  end

  it 'handles an update from a fixer callback' do
    media_resource.update_from_fixer(fixer_task)
    media_resource.mime_type.must_equal 'test/type'
    media_resource.file_size.must_equal 1111
    media_resource.sample_rate.must_equal 44444
    media_resource.channels.must_equal 3
    media_resource.duration.must_equal 2222
    media_resource.bit_rate.must_equal 55
  end

  it 'defaults bad content type from a fixer callback to audio/mpeg' do
    media_resource.mime_type.must_equal 'audio/mpeg'
    fixer_task['task']['result_details']['info']['content_type'] = 'application/octect-stream'
    media_resource.update_from_fixer(fixer_task)
    media_resource.mime_type.must_equal 'audio/mpeg'

    media_resource.mime_type = nil
    fixer_task['task']['result_details']['info']['content_type'] = 'application/octect-stream'
    media_resource.update_from_fixer(fixer_task)
    media_resource.mime_type.must_equal 'audio/mpeg'
  end
end
