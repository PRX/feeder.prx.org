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

  it 'initializes guid and url' do
    mr = MediaResource.new(episode: episode)
    mr.guid.wont_be_nil
    mr.url.wont_be_nil
  end

  it 'answers if it is processed' do
    media_resource.wont_be :is_processed?
    media_resource.complete!
    media_resource.must_be :is_processed?
  end

  it 'provides audio url based on guid' do
    media_resource.media_url.must_match /http:\/\/test-f.prxu.org\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/
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
