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
      Result: [{Task: 'Copy', Other: 'Things'}]
    })
  end

  it 'handles non-rexif messages' do
    TestParser.rexif_callback_job_id({}).must_be_nil
    TestParser.rexif_callback_status({}).must_be_nil
    TestParser.rexif_callback_time({}).must_be_nil
    TestParser.rexif_callback_results({}).must_be_nil
  end

  it 'parses rexif received callback messages' do
    TestParser.rexif_callback_job_id(rexif_received_callback).must_equal 'the-job-id'
    TestParser.rexif_callback_status(rexif_received_callback).must_equal 'processing'
    TestParser.rexif_callback_time(rexif_received_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.rexif_callback_results(rexif_received_callback).must_be_nil
  end

  it 'parses rexif error callback messages' do
    TestParser.rexif_callback_job_id(rexif_error_callback).must_equal 'the-job-id'
    TestParser.rexif_callback_status(rexif_error_callback).must_equal 'error'
    TestParser.rexif_callback_time(rexif_error_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.rexif_callback_results(rexif_error_callback).must_be_nil
  end

  it 'parses rexif successful callback messages' do
    TestParser.rexif_callback_job_id(rexif_success_callback).must_equal 'the-job-id'
    TestParser.rexif_callback_status(rexif_success_callback).must_equal 'complete'
    TestParser.rexif_callback_time(rexif_success_callback).must_equal Time.parse('2012-12-21T12:34:56Z')
    TestParser.rexif_callback_results(rexif_success_callback).must_equal [
      {'Task' => 'Copy', 'Other' => 'Things'}
    ]
  end
end
