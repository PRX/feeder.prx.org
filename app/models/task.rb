require 'hash_serializer'

# keeps track of status of tasks to fixer and any other systems

class Task < ActiveRecord::Base
  belongs_to :owner, polymorphic: true
  serialize :options, HashSerializer
  serialize :result, HashSerializer
  enum status: [ :started, :created, :processing, :complete, :error, :retrying, :cancelled ]

  before_validation { self.status ||= :started }

  # convenient scopes for subclass types
  [:copy_audio].each do |subclass|
    classname = "Tasks::#{subclass.to_s.camelize}Task"
    scope subclass, -> { where('type = ?', classname) }
  end

  def self.fixer_callback(fixer_task)
    Task.transaction do
      job_id = fixer_task['task']['job']['id']
      task = where(job_id: job_id).lock(true).first
      task.fixer_callback(fixer_task) if task
    end
  end

  def fixer_callback(fixer_task)
    ft = fixer_task['task']
    new_status = ft['result_details']['status']
    new_logged_at = ft['result_details']['logged_at']
    if logged_at.nil? || (new_logged_at > logged_at)
      update_attributes!(
        status: new_status,
        logged_at: new_logged_at,
        result: fixer_task
      )
      task_status_changed(fixer_task)
    end
  end

  def task_status_changed(fixer_task)
  end
end
