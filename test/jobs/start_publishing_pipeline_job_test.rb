require "test_helper"

describe StartPublishingPipelineJob do
  it "calls start_pipeline!" do
    mock = Minitest::Mock.new
    mock.expect :call, ->(_podcast) {}, [Podcast]
    PublishingPipelineState.stub :start_pipeline!, mock do
      StartPublishingPipelineJob.perform_now(create(:podcast))
    end

    mock.verify
  end
end
