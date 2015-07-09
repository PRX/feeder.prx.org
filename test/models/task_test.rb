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

  it 'class can handle fixer callback' do
    t = Task.create
    ft = fixer_task
    ft['task']['job']['id'] = t.id
    Task.fixer_callback(ft)
  end

  it 'can handle fixer callback' do
    t = Task.create
    t.fixer_callback(fixer_task)
    t.must_be :complete?
    t.logged_at.must_equal Time.parse('1/1/2010')
  end
end
