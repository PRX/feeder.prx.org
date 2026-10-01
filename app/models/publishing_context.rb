# The publishing worker's identity for the current job, so code deep in a
# publish (e.g. Apple wait loops) can beat without threading pub_item through
class PublishingContext < ActiveSupport::CurrentAttributes
  attribute :podcast, :publishing_queue_item

  # Does nothing outside a publish job (console, tests, other callers)
  def self.heartbeat!
    return unless podcast && publishing_queue_item

    PublishingPipelineState.heartbeat!(podcast, publishing_queue_item)
  end
end
