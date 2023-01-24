require "test_helper"

describe ApplicationWorker do
  let(:worker) { ApplicationWorker.new }
  let(:msg) { {subject: :foo, action: :bar} }

  it "adds queue name prefix" do
    assert_equal ApplicationWorker.prefix_name("foo"), "test_feeder_foo"
  end

  it "lists announce queues" do
    assert_equal ApplicationWorker.announce_queues("foo", ["bar", "wat"]),
      ["test_announce_feeder_foo_bar", "test_announce_feeder_foo_wat"]
  end

  it "determines the delegate method" do
    assert_equal worker.delegate_method(msg), "receive_foo_bar"
  end

  it "has a logger" do
    assert_not_nil worker.logger
    assert worker.logger.is_a?(::Logger)
  end
end
