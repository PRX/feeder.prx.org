require 'test_helper'

class TestParser
  include RexifParser
  attr_accessor :result
end

describe RexifParser do
  let(:rexif_callback) do
    {Time: '2012-12-21T12:34:56Z', Timestamp: 1356093296.123}
  end

  let(:rexif_received_callback) do
    rexif_callback.merge(JobReceived: {Job: {Id: 'the-job-id'}})
  end

  let(:rexif_error_callback) do
    rexif_callback.merge(JobResult: {Job: {Id: 'the-job-id'}, Error: {Any: 'Thing'}})
  end

  let(:rexif_success_callback) do
    rexif_callback.merge(JobResult: {
      Job: {Id: 'the-job-id'},
      Result: [rexif_copy_result, rexif_inspect_result]
    })
  end

  let(:rexif_copy_result) do
    {Task: 'Copy', Other: 'Things'}.with_indifferent_access
  end

  let(:rexif_inspect_result) do
    {
      Task: 'Inspect',
      Inspection: {
        size: '32980032',
        audio: {
          duration: 1371437,
          format: 'mp3',
          bitrate: '192000',
          frequency: '48000',
          channels: 2,
          layout: 'stereo',
          layer: '                        3',
          samples: nil,
          frames: '                       57143'
        }
      }
    }.with_indifferent_access
  end

  it 'handles non-rexif messages' do
    TestParser.rexif_callback_job_id({}).must_be_nil
    TestParser.rexif_callback_status({}).must_be_nil
    TestParser.rexif_callback_time({}).must_be_nil
    TestParser.rexif_callback_copy({}).must_be_nil
    TestParser.rexif_callback_inspect({}).must_be_nil
  end

  it 'parses rexif received callback messages' do
    TestParser.rexif_callback_job_id(rexif_received_callback).must_equal 'the-job-id'
    TestParser.rexif_callback_status(rexif_received_callback).must_equal 'processing'
    TestParser.rexif_callback_time(rexif_received_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.rexif_callback_copy(rexif_received_callback).must_be_nil
    TestParser.rexif_callback_inspect(rexif_received_callback).must_be_nil
  end

  it 'parses rexif error callback messages' do
    TestParser.rexif_callback_job_id(rexif_error_callback).must_equal 'the-job-id'
    TestParser.rexif_callback_status(rexif_error_callback).must_equal 'error'
    TestParser.rexif_callback_time(rexif_error_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.rexif_callback_copy(rexif_error_callback).must_be_nil
    TestParser.rexif_callback_inspect(rexif_error_callback).must_be_nil
  end

  it 'parses rexif successful callback messages' do
    TestParser.rexif_callback_job_id(rexif_success_callback).must_equal 'the-job-id'
    TestParser.rexif_callback_status(rexif_success_callback).must_equal 'complete'
    TestParser.rexif_callback_time(rexif_success_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.rexif_callback_copy(rexif_success_callback).must_equal(rexif_copy_result)
    TestParser.rexif_callback_inspect(rexif_success_callback).must_equal(rexif_inspect_result)
  end

  it 'parses rexif audio metadata' do
    model = TestParser.new
    model.result = rexif_success_callback
    model.rexif_callback_audio_meta.must_equal({
      mime_type: 'audio/mpeg',
      medium: 'audio',
      file_size: 32980032,
      sample_rate: 48000,
      channels: 2,
      duration: 1371.437,
      bit_rate: 192,
    })
  end

end
