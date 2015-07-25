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
          'logged_at' => Time.parse('1/1/2010')
        }
      }
    }
  end

  let(:task) { Task.create }

  it 'knows what bucket to drop the file in' do
    task.feeder_storage_bucket.must_equal 'test-prx-feed'
  end

  it 'uses an sqs queue for callbacks' do
    task.fixer_call_back_queue.must_equal 'sqs://us-east-1/test_feeder_fixer_callback'
  end

  it 'creates a fixer job' do
    task.fixer_sqs_client = SqsMock.new
    job = task.fixer_copy_file(destination: 'dest', source: 'src', job_type: 'file')
    job[:job][:job_type].must_equal 'file'
  end

  it 'class can handle fixer callback' do
    ft = fixer_task
    ft['task']['job']['id'] = task.id
    Task.fixer_callback(ft)
  end

  it 'can handle fixer callback' do
    task.fixer_callback(fixer_task)
    task.must_be :complete?
    task.logged_at.must_equal Time.parse('1/1/2010')
  end
end
