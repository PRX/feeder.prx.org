require "test_helper"

describe ApplicationWorker do
  let(:worker) { ApplicationWorker.new }
  let(:msg) { {subject: :foo, action: :bar} }

  it "adds queue name prefix" do
    assert_equal ApplicationWorker.prefix_name("foo"), "test_feeder_foo"
  end

  it "has a logger" do
    assert_not_nil worker.logger
    assert worker.logger.is_a?(::Logger)
  end
end
