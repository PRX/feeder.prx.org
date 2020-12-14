require 'test_helper'

describe Task do

  let(:porter_task) { build(:porter_job_results) }

  let(:task) { Task.create }

  it 'knows what bucket to drop the file in' do
    assert_equal task.feeder_storage_bucket, 'test-prx-feed'
  end

  it 'uses an sqs queue for callbacks' do
    r, ENV['AWS_REGION'], ENV['FIXER_CALLBACK_QUEUE'], q = ENV['AWS_REGION'], 'us-east-1', nil, ENV['FIXER_CALLBACK_QUEUE']
    assert_equal task.callback_queue, 'sqs://us-east-1/test_feeder_fixer_callback'
    ENV['AWS_REGION'], ENV['FIXER_CALLBACK_QUEUE'] = r, q
  end

  it 'handles porter callbacks' do
    task.update_attribute(:job_id, porter_task['JobResult']['Job']['Id'])
    assert task.started?
    Task.callback(porter_task)
    assert task.reload.complete?
    assert_equal task.logged_at, Time.parse('2012-12-21T12:34:56Z')
  end

  it 'ignores porter task results' do
    task.update_attribute(:job_id, porter_task['JobResult']['Job']['Id'])
    assert task.started?
    assert_nil task.logged_at

    porter_task['TaskResult'] = porter_task.delete('JobResult')
    Task.callback(porter_task)
    assert task.reload.started?
    assert_nil task.logged_at
  end
end
