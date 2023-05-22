require "test_helper"

describe PorterCallbackWorker do
  let(:worker) { PorterCallbackWorker.new }

  it "calls task" do
    job = Minitest::Mock.new
    Task.stub(:callback, true) do
      worker.perform({}, job)
    end
  end
end
