require "prx_access"

class ApplicationWorker
  include PrxAccess
  include Shoryuken::Worker

  attr_accessor :message

  def self.prefix_name(name)
    [prefix, application, name].join("_")
  end

  def self.announce_queues(model, actions)
    actions.map do |action|
      [prefix, "announce", application, model, action].join("_")
    end
  end

  def self.application
    "feeder"
  end

  def self.prefix
    Rails.configuration.active_job.queue_name_prefix
  end

  def announce_perform(event)
    self.message = event.deep_symbolize_keys
    method = delegate_method(message)

    if respond_to?(method)
      public_send(method, message[:body])
    else
      raise "`#{self.class.name}` subscribed, but doesn't implement " \
              "`#{delegate_method}` for '#{event.inspect}'"
    end
  end

  def action
    (message || {})[:action]
  end

  def subject
    (message || {})[:subject]
  end

  def delegate_method(message)
    ["receive", message[:subject], message[:action]].join("_")
  end

  def logger
    Shoryuken.logger
  end
end
