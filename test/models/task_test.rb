require 'test_helper'

describe Task do

  let(:porter_task) { build(:porter_job_results) }

  let(:task) { Task.create }

  it 'knows what bucket to drop the file in' do
    task.feeder_storage_bucket.must_equal 'test-prx-feed'
  end

  it 'uses an sqs queue for callbacks' do
    r, ENV['AWS_REGION'], ENV['FIXER_CALLBACK_QUEUE'], q = ENV['AWS_REGION'], 'us-east-1', nil, ENV['FIXER_CALLBACK_QUEUE']
    task.callback_queue.must_equal 'sqs://us-east-1/test_feeder_fixer_callback'
    ENV['AWS_REGION'], ENV['FIXER_CALLBACK_QUEUE'] = r, q
  end

  it 'handles porter callbacks' do
    task.update_attribute(:job_id, porter_task['JobResult']['Job']['Id'])
    task.must_be :started?
    Task.callback(porter_task)
    task.reload.must_be :complete?
    task.logged_at.must_equal Time.parse('2012-12-21T12:34:56Z')
  end

  it 'ignores porter task results' do
    task.update_attribute(:job_id, porter_task['JobResult']['Job']['Id'])
    task.must_be :started?
    task.logged_at.must_be_nil

    porter_task['TaskResult'] = porter_task.delete('JobResult')
    Task.callback(porter_task)
    task.reload.must_be :started?
    task.logged_at.must_be_nil
  end
end
