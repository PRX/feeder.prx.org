require "test_helper"

describe PorterCallbackWorker do
  let(:worker) { PorterCallbackWorker.new }

  it "calls task" do
    mock = Minitest::Mock.new
    mock.expect(:call, nil, ["some-data"])

    Task.stub(:callback, mock) do
      worker.perform({}, "some-data")
    end

    assert mock.verify
  end
end
