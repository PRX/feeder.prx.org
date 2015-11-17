require 'test_helper'

class TaskTest < ActiveSupport::TestCase

  let(:fixer_task) do
    {
      'task' => {
        'job' => {
          'id' => 12345
        },
        'result_details' => {
          'status' => 'complete',
          'logged_at' => "2010-01-01T00:00:00.000Z"
        }
      }
    }
  end

  let(:task) { Task.create }

  it 'knows what bucket to drop the file in' do
    task.feeder_storage_bucket.must_equal 'test-prx-feed'
  end

  it 'uses an sqs queue for callbacks' do
    r, ENV['AWS_REGION'], ENV['FIXER_CALLBACK_QUEUE'], q = ENV['AWS_REGION'], 'us-east-1', nil, ENV['FIXER_CALLBACK_QUEUE']
    task.fixer_call_back_queue.must_equal 'sqs://us-east-1/test_feeder_fixer_callback'
    ENV['AWS_REGION'], ENV['FIXER_CALLBACK_QUEUE'] = r, q
  end

  it 'creates a fixer job' do
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      job = task.fixer_copy_file(destination: 'dest', source: 'src', job_type: 'file')
      job[:job][:job_type].must_equal 'file'
    end
  end

  it 'class can handle fixer callback' do
    ft = fixer_task
    ft['task']['job']['id'] = task.id
    Task.fixer_callback(ft)
  end

  it 'can handle fixer callback' do
    task.fixer_callback(fixer_task)
    task.must_be :complete?
    task.logged_at.must_equal Time.parse("2010-01-01T00:00:00.000Z")
  end
end
