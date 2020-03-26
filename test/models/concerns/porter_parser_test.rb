require 'test_helper'

class TestParser
  include PorterParser
  attr_accessor :result
end

describe PorterParser do
  it 'handles non-porter messages' do
    TestParser.porter_callback_job_id({}).must_be_nil
    TestParser.porter_callback_status({}).must_be_nil
    TestParser.porter_callback_time({}).must_be_nil
    TestParser.porter_callback_copy({}).must_be_nil
    TestParser.porter_callback_inspect({}).must_be_nil
  end

  it 'parses porter job received callback messages' do
    porter_received_callback = build(:porter_job_received)
    TestParser.porter_callback_job_id(porter_received_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(porter_received_callback).must_equal 'processing'
    TestParser.porter_callback_time(porter_received_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.porter_callback_copy(porter_received_callback).must_be_nil
    TestParser.porter_callback_inspect(porter_received_callback).must_be_nil
  end

  it 'ignores porter task result callback messages' do
    task_result_callback = build(:porter_task_result)
    TestParser.porter_callback_job_id(task_result_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(task_result_callback).must_be_nil
  end

  it 'ignores porter task error callback messages' do
    task_error_callback = build(:porter_task_error)
    TestParser.porter_callback_job_id(task_error_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(task_error_callback).must_be_nil
  end

  it 'parses porter ingest failed callback messages' do
    porter_404_callback = build(:porter_job_ingest_failed)
    TestParser.porter_callback_job_id(porter_404_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(porter_404_callback).must_equal 'error'
    TestParser.porter_callback_time(porter_404_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.porter_callback_copy(porter_404_callback).must_be_nil
    TestParser.porter_callback_inspect(porter_404_callback).must_be_nil
  end

  it 'parses porter job failed callback messages' do
    porter_error_callback = build(:porter_job_failed)
    TestParser.porter_callback_job_id(porter_error_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(porter_error_callback).must_equal 'error'
    TestParser.porter_callback_time(porter_error_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.porter_callback_copy(porter_error_callback).must_be_nil
    TestParser.porter_callback_inspect(porter_error_callback).must_be_nil
  end

  it 'parses porter successful callback messages' do
    porter_success_callback = build(:porter_job_results)
    TestParser.porter_callback_job_id(porter_success_callback).must_equal 'the-job-id'
    TestParser.porter_callback_status(porter_success_callback).must_equal 'complete'
    TestParser.porter_callback_time(porter_success_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.porter_callback_copy(porter_success_callback).must_equal(build(:porter_copy_result))
    TestParser.porter_callback_inspect(porter_success_callback).must_equal(build(:porter_inspect_audio_result))
  end

  it 'parses porter audio metadata' do
    model = TestParser.new
    model.result = build(:porter_job_results)
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
    porter_success_callback = build(:porter_job_results).tap do |r|
      r[:JobResult][:TaskResults][1] = build(:porter_inspect_video_result)
    end

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
      frame_rate: 24, # (24000 / 1001).round
      width: 640,
      height: 360
    })
  end

  it 'parses porter mime type' do
    porter_success_callback = build(:porter_job_results).tap do |r|
      r[:JobResult][:TaskResults][1][:Inspection][:MIME] = 'image/png'
    end
    model = TestParser.new
    model.result = porter_success_callback
    model.porter_callback_media_meta[:mime_type].must_equal('image/png')
    model.porter_callback_media_meta[:medium].must_equal('image')
  end
end
