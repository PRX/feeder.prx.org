require "test_helper"

class TestParser
  include PorterParser
  attr_accessor :result
end

describe PorterParser do
  it "handles non-porter messages" do
    assert_nil TestParser.porter_callback_job_id({})
    assert_nil TestParser.porter_callback_status({})
    assert_nil TestParser.porter_callback_time({})
  end

  it "parses porter job received callback messages" do
    porter_received_callback = build(:porter_job_received)
    assert_equal TestParser.porter_callback_job_id(porter_received_callback), "the-job-id"
    assert_equal TestParser.porter_callback_status(porter_received_callback), "processing"
    assert_equal TestParser.porter_callback_time(porter_received_callback), Time.parse("2012-12-21T12:34:56Z")
  end

  it "ignores porter task result callback messages" do
    task_result_callback = build(:porter_task_result)
    assert_equal TestParser.porter_callback_job_id(task_result_callback), "the-job-id"
    assert_nil TestParser.porter_callback_status(task_result_callback)
  end

  it "ignores porter task error callback messages" do
    task_error_callback = build(:porter_task_error)
    assert_equal TestParser.porter_callback_job_id(task_error_callback), "the-job-id"
    assert_nil TestParser.porter_callback_status(task_error_callback)
  end

  it "parses porter ingest failed callback messages" do
    porter_404_callback = build(:porter_job_ingest_failed)
    assert_equal TestParser.porter_callback_job_id(porter_404_callback), "the-job-id"
    assert_equal TestParser.porter_callback_status(porter_404_callback), "error"
    assert_equal TestParser.porter_callback_time(porter_404_callback), Time.parse("2012-12-21T12:34:56Z")
  end

  it "parses porter job failed callback messages" do
    porter_error_callback = build(:porter_job_failed)
    assert_equal TestParser.porter_callback_job_id(porter_error_callback), "the-job-id"
    assert_equal TestParser.porter_callback_status(porter_error_callback), "error"
    assert_equal TestParser.porter_callback_time(porter_error_callback), Time.parse("2012-12-21T12:34:56Z")
  end

  it "parses porter successful callback messages" do
    porter_success_callback = build(:porter_job_results)
    assert_equal TestParser.porter_callback_job_id(porter_success_callback), "the-job-id"
    assert_equal TestParser.porter_callback_status(porter_success_callback), "complete"
    assert_equal TestParser.porter_callback_time(porter_success_callback), Time.parse("2012-12-21T12:34:56Z")
  end

  it "parses porter task results" do
    model = TestParser.new
    model.result = build(:porter_job_results)
    copy_result = build(:porter_copy_result)
    inspect_result = build(:porter_inspect_audio_result)

    assert_nil model.porter_callback_task_result("foo")
    assert_equal copy_result, model.porter_callback_task_result("Copy")
    assert_equal copy_result, model.porter_callback_task_result(:Copy)
    assert_equal inspect_result, model.porter_callback_task_result("Inspect")
    assert_equal inspect_result, model.porter_callback_task_result(:Inspect)
  end

  it "parses porter inspect info" do
    model = TestParser.new
    assert_empty model.porter_callback_inspect

    model.result = build(:porter_job_results)
    inspect_result = build(:porter_inspect_audio_result)
    assert_equal inspect_result[:Inspection], model.porter_callback_inspect
  end

  it "parses porter mime type" do
    model = TestParser.new
    assert_nil model.porter_callback_mime

    model.result = build(:porter_job_results)
    assert_equal "audio/mpeg", model.porter_callback_mime

    model.result[:JobResult][:TaskResults][1][:Inspection][:MIME] = "foo/bar"
    assert_equal "foo/bar", model.porter_callback_mime

    # inferred for "Audio" inspect result
    model.result[:JobResult][:TaskResults][1][:Inspection][:MIME] = nil
    assert_equal "audio/mpeg", model.porter_callback_mime

    # not inferred for other inspect results
    model.result[:JobResult][:TaskResults][1][:Inspection][:Audio] = nil
    assert_nil model.porter_callback_mime
  end

  it "parses porter file sizes" do
    model = TestParser.new
    assert_nil model.porter_callback_size

    model.result = build(:porter_job_results)
    assert_equal 32980032, model.porter_callback_size
  end
end
