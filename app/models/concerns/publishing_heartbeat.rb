# Beats the publish job's heartbeat on entry to every method of the including
# class, so long-running work proves liveness without explicit checkpoints.
# The heartbeat raises PublishingPipelineState::LostOwnershipError once the
# pipeline was expired, which stops the work at the next method call.
module PublishingHeartbeat
  extend ActiveSupport::Concern

  # Beat at most this often; well inside PublishingPipelineState::HEARTBEAT_STALE_AFTER
  HEARTBEAT_INTERVAL = 30.seconds.freeze

  class_methods do
    # Call at the bottom of the class: only methods defined so far are wrapped
    def heartbeat_around_all_methods(except: [])
      skip = [:initialize, :heartbeat!, *except]
      privates = private_instance_methods(false)
      protecteds = protected_instance_methods(false)
      names = (public_instance_methods(false) + protecteds + privates) - skip

      prepend(Module.new do
        names.each do |name|
          define_method(name) do |*args, **kwargs, &block|
            heartbeat!
            super(*args, **kwargs, &block)
          end
          private name if privates.include?(name)
          protected name if protecteds.include?(name)
        end
      end)
    end
  end

  # Calls @heartbeat, set by the including class, throttled to HEARTBEAT_INTERVAL.
  # Does nothing without a heartbeat.
  def heartbeat!
    return unless @heartbeat
    return if @last_beat_at && @last_beat_at > HEARTBEAT_INTERVAL.ago

    @heartbeat.call
    @last_beat_at = Time.current
  end
end
