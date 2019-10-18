require 'test_helper'

class TestParser
  include PorterParser
  attr_accessor :result
end

describe PorterParser do
  let(:porter_callback) do
    {Time: '2012-12-21T12:34:56Z', Timestamp: 1356093296.123}
  end

  let(:porter_received_callback) do
    porter_callback.merge(JobReceived: {Job: {Id: 'the-job-id'}})
  end

  let(:porter_error_callback) do
    porter_callback.merge(JobResult: {Job: {Id: 'the-job-id'}, Error: {Any: 'Thing'}})
  end

  let(:porter_success_callback) do
    porter_callback.merge(JobResult: {
      Job: {Id: 'the-job-id'},
      Result: [porter_copy_result, porter_inspect_audio]
    })
  end

  let(:porter_copy_result) do
    {Task: 'Copy', Other: 'Things'}.with_indifferent_access
  end

  let(:porter_inspect_audio) do
    {
      Task: 'Inspect',
      Inspection: {
        Extension: 'mp3',
        MIME: 'audio/mpeg',
        Size: '32980032',
        Audio: {
          Duration: 1371437,
          Format: 'mp3',
          Bitrate: '192000',
          Frequency: '48000',
          Channels: 2,
          Layout: 'stereo',
          Layer: '3',
          Samples: nil,
          Frames: '57143'
        }
      }
    }.with_indifferent_access
  end

  let(:porter_inspect_video) do
    {
      Task: 'Inspect',
      Inspection: {
        Extension: 'mp4',
        MIME: 'video/mp4',
        Size: '16996018',
        Audio: {
          Duration: 158035,
          Format: 'aac',
          Bitrate: '109507',
          Frequency: '44100',
          Channels: 2,
          Layout: 'stereo'
        },
        Video: {
          Duration: 157991,
          Format: 'h264',
          Bitrate: '747441',
          Width: 640,
          Height: 360,
          Aspect: '16:9',
          Framerate: '24000/1001'
        }
      }
    }.with_indifferent_access
  end

  it 'handles non-porter messages' do
    TestParser.porter_callback_job_id({}).must_be_nil
    TestParser.porter_callback_status({}).must_be_nil
    TestParser.porter_callback_time({}).must_be_nil
    TestParser.porter_callback_copy({}).must_be_nil
    TestParser.porter_callback_inspect({}).must_be_nil
  end

  it 'parses porter received callback messages' do
    TestParser.porter_callback_job_id(porter_received_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(porter_received_callback).must_equal 'processing'
    TestParser.porter_callback_time(porter_received_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.porter_callback_copy(porter_received_callback).must_be_nil
    TestParser.porter_callback_inspect(porter_received_callback).must_be_nil
  end

  it 'parses porter error callback messages' do
    TestParser.porter_callback_job_id(porter_error_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(porter_error_callback).must_equal 'error'
    TestParser.porter_callback_time(porter_error_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.porter_callback_copy(porter_error_callback).must_be_nil
    TestParser.porter_callback_inspect(porter_error_callback).must_be_nil
  end

  it 'parses porter successful callback messages' do
    TestParser.porter_callback_job_id(porter_success_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(porter_success_callback).must_equal 'complete'
    TestParser.porter_callback_time(porter_success_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.porter_callback_copy(porter_success_callback).must_equal(porter_copy_result)
    TestParser.porter_callback_inspect(porter_success_callback).must_equal(porter_inspect_audio)
  end

  it 'parses porter audio metadata' do
    model = TestParser.new
    model.result = porter_success_callback
    model.porter_callback_media_meta.must_equal({
      mime_type: 'audio/mpeg',
      medium: 'audio',
      file_size: 32980032,
      sample_rate: 48000,
      channels: 2,
      duration: 1371.437,
      bit_rate: 192,
    })
  end

  it 'parses porter audio metadata' do
    model = TestParser.new
    model.result = porter_success_callback
    model.porter_callback_media_meta.must_equal({
      mime_type: 'audio/mpeg',
      medium: 'audio',
      file_size: 32980032,
      sample_rate: 48000,
      channels: 2,
      duration: 1371.437,
      bit_rate: 192,
    })
  end

  it 'parses porter video metadata' do
    porter_success_callback[:JobResult][:Result] = [porter_copy_result, porter_inspect_video]

    model = TestParser.new
    model.result = porter_success_callback
    model.porter_callback_media_meta.must_equal({
      mime_type: 'video/mp4',
      medium: 'video',
      file_size: 16996018,
      sample_rate: 44100,
      channels: 2,
      duration: 157.991,
      bit_rate: 747,
      frame_rate: '24000/1001',
      width: 640,
      height: 360
    })
  end

  it 'parses porter mime type' do
    porter_inspect_audio[:Inspection][:MIME] = 'image/png'
    model = TestParser.new
    model.result = porter_success_callback
    model.porter_callback_media_meta[:mime_type].must_equal('image/png')
    model.porter_callback_media_meta[:medium].must_equal('image')
  end
end
