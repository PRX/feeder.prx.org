require 'test_helper'

class TestParser
  include PorterParser
  attr_accessor :result
end

describe PorterParser do
  it 'handles non-porter messages' do
    assert_nil TestParser.porter_callback_job_id({})
    assert_nil TestParser.porter_callback_status({})
    assert_nil TestParser.porter_callback_time({})
    assert_nil TestParser.porter_callback_copy({})
    assert_nil TestParser.porter_callback_inspect({})
  end

  it 'parses porter job received callback messages' do
    porter_received_callback = build(:porter_job_received)
    assert_equal TestParser.porter_callback_job_id(porter_received_callback), 'the-job-id'
    assert_equal TestParser.porter_callback_status(porter_received_callback), 'processing'
    assert_equal TestParser.porter_callback_time(porter_received_callback), Time.parse('2012-12-21T12:34:56Z')
    assert_nil TestParser.porter_callback_copy(porter_received_callback)
    assert_nil TestParser.porter_callback_inspect(porter_received_callback)
  end

  it 'ignores porter task result callback messages' do
    task_result_callback = build(:porter_task_result)
    assert_equal TestParser.porter_callback_job_id(task_result_callback), 'the-job-id'
    assert_nil TestParser.porter_callback_status(task_result_callback)
  end

  it 'ignores porter task error callback messages' do
    task_error_callback = build(:porter_task_error)
    assert_equal TestParser.porter_callback_job_id(task_error_callback), 'the-job-id'
    assert_nil TestParser.porter_callback_status(task_error_callback)
  end

  it 'parses porter ingest failed callback messages' do
    porter_404_callback = build(:porter_job_ingest_failed)
    assert_equal TestParser.porter_callback_job_id(porter_404_callback), 'the-job-id'
    assert_equal TestParser.porter_callback_status(porter_404_callback), 'error'
    assert_equal TestParser.porter_callback_time(porter_404_callback), Time.parse('2012-12-21T12:34:56Z')
    assert_nil TestParser.porter_callback_copy(porter_404_callback)
    assert_nil TestParser.porter_callback_inspect(porter_404_callback)
  end

  it 'parses porter job failed callback messages' do
    porter_error_callback = build(:porter_job_failed)
    assert_equal TestParser.porter_callback_job_id(porter_error_callback), 'the-job-id'
    assert_equal TestParser.porter_callback_status(porter_error_callback), 'error'
    assert_equal TestParser.porter_callback_time(porter_error_callback), Time.parse('2012-12-21T12:34:56Z')
    assert_nil TestParser.porter_callback_copy(porter_error_callback)
    assert_nil TestParser.porter_callback_inspect(porter_error_callback)
  end

  it 'parses porter successful callback messages' do
    porter_success_callback = build(:porter_job_results)
    assert_equal TestParser.porter_callback_job_id(porter_success_callback), 'the-job-id'
    assert_equal TestParser.porter_callback_status(porter_success_callback), 'complete'
    assert_equal TestParser.porter_callback_time(porter_success_callback), Time.parse('2012-12-21T12:34:56Z')
    assert_equal TestParser.porter_callback_copy(porter_success_callback), build(:porter_copy_result)
    assert_equal TestParser.porter_callback_inspect(porter_success_callback), build(:porter_inspect_audio_result)
  end

  it 'parses porter audio metadata' do
    model = TestParser.new
    model.result = build(:porter_job_results)
    assert_equal(model.porter_callback_media_meta, {
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
    assert_equal(model.porter_callback_media_meta, {
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
    assert_equal model.porter_callback_media_meta[:mime_type], 'image/png'
    assert_equal model.porter_callback_media_meta[:medium], 'image'
  end
end
