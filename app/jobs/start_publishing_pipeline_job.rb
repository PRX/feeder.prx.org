class StartPublishingPipelineJob < ApplicationJob
  queue_as :feeder_publishing

  def perform(podcast)
    PublishingPipelineState.start_pipeline!(podcast)
  end
end
