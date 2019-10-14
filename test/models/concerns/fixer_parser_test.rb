require 'test_helper'

class TestParser
  include FixerParser
  attr_accessor :result
end

describe FixerParser do
  let(:fixer_callback) do
    {
      task: {
        job: {id: 'the-job-id'},
        result_details: {status: 'complete', logged_at: '2019-10-10T22:14:43.071Z', info: fixer_callback_info}
      }
    }
  end
  let(:fixer_callback_info) do
    {
      content_type: 'audio/mpeg',
      size: 32980032,
      sample_rate: 48000,
      channels: 2,
      length: 1371.437333,
      bit_rate: 192
    }.with_indifferent_access
  end

  it 'handles non-fixer messages' do
    TestParser.fixer_callback_job_id({}).must_be_nil
    TestParser.fixer_callback_status({}).must_be_nil
    TestParser.fixer_callback_time({}).must_be_nil
    TestParser.fixer_callback_info({}).must_be_nil
  end

  it 'parses fixer callback messages' do
    TestParser.fixer_callback_job_id(fixer_callback).must_equal 'the-job-id'
    TestParser.fixer_callback_status(fixer_callback).must_equal 'complete'
    TestParser.fixer_callback_time(fixer_callback).must_equal Time.parse('2019-10-10T22:14:43.071Z')
    TestParser.fixer_callback_info(fixer_callback).must_equal fixer_callback_info
  end

  it 'handles non-fixer audio metadata' do
    model = TestParser.new
    model.result = {any: 'data'}
    model.fixer_callback_audio_meta.must_be_nil
  end

  it 'parses fixer audio metadata' do
    model = TestParser.new
    model.result = fixer_callback
    model.fixer_callback_audio_meta.must_equal({
      mime_type: 'audio/mpeg',
      medium: 'audio',
      file_size: 32980032,
      sample_rate: 48000,
      channels: 2,
      duration: 1371.437333,
      bit_rate: 192,
    })
  end

  it 'defaults a mime type' do
    TestParser.new.fixer_callback_mime({}).must_equal 'audio/mpeg'
    TestParser.new.fixer_callback_mime({content_type: ''}).must_equal 'audio/mpeg'
    TestParser.new.fixer_callback_mime({content_type: 'application/octet-stream'}).must_equal 'audio/mpeg'
    TestParser.new.fixer_callback_mime({content_type: 'anything'}).must_equal 'anything'
  end
end
