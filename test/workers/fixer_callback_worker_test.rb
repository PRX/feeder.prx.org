require "test_helper"

describe FixerCallbackWorker do
  let(:worker) { FixerCallbackWorker.new }

  it "calls task" do
    job = Minitest::Mock.new
    Task.stub(:callback, true) do
      worker.perform({}, job)
    end
  end
end
