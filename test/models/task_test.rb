require 'test_helper'

describe Task do

  let(:fixer_task) do
    {
      'task' => {
        'job' => {
          'id' => 11111111
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
    task.callback_queue.must_equal 'sqs://us-east-1/test_feeder_fixer_callback'
    ENV['AWS_REGION'], ENV['FIXER_CALLBACK_QUEUE'] = r, q
  end

  it 'creates a fixer job' do
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      task.start!
      task.job_id.must_equal '11111111'
      task.options[:callback].must_match /^sqs:\/\//
    end
  end

  it 'can handle fixer callback' do
    task.update_attribute(:job_id, fixer_task['task']['job']['id'])
    task.must_be :started?
    Task.callback(fixer_task)
    task.reload.must_be :complete?
    task.logged_at.must_equal Time.parse("2010-01-01T00:00:00.000Z")
  end

  it 'encodes fixer query params' do
    task.fixer_query.must_equal 'x-fixer-public=true&x-fixer-Cache-Control=max-age%3D86400'
    task.fixer_query('foo': 'b a r').must_equal 'x-fixer-public=true&x-fixer-Cache-Control=max-age%3D86400&foo=b+a+r'
    m, ENV['FIXER_CACHE_MAX_AGE'] = ENV['FIXER_CACHE_MAX_AGE'], '1234'
    task.fixer_query.must_equal 'x-fixer-public=true&x-fixer-Cache-Control=max-age%3D1234'
    ENV['FIXER_CACHE_MAX_AGE'] = m
  end
end
