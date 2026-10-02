require "test_helper"

class PublishingHeartbeatTest < ActiveSupport::TestCase
  let(:klass) do
    Class.new do
      include PublishingHeartbeat

      def step(arg, key: nil, &block)
        [arg, key, block&.call]
      end

      def run(heartbeat)
        @heartbeat = heartbeat
        @last_beat_at = nil
        yield
      end

      private

      def helper
        :helper
      end

      heartbeat_around_all_methods(except: [:run])

      public

      def defined_after
        :after
      end
    end
  end

  let(:model) { klass.new }

  it "does nothing without a heartbeat" do
    assert_nil model.heartbeat!
    assert_equal [1, 2, 3], model.step(1, key: 2) { 3 }
  end

  it "beats on entry to wrapped methods, passing through args, kwargs and blocks" do
    beats = 0

    result = model.run(-> { beats += 1 }) { model.step(1, key: 2) { 3 } }

    assert_equal [1, 2, 3], result
    assert_equal 1, beats
  end

  it "keeps private methods private" do
    assert_raises(NoMethodError) { model.helper }
    assert_equal :helper, model.send(:helper)
  end

  it "only wraps methods defined before heartbeat_around_all_methods" do
    beats = 0

    model.run(-> { beats += 1 }) { model.defined_after }

    assert_equal 0, beats
  end

  it "throttles beats to the heartbeat interval" do
    beats = 0

    model.run(-> { beats += 1 }) do
      model.step(1)
      model.send(:helper)
      travel PublishingHeartbeat::HEARTBEAT_INTERVAL - 1.second
      model.step(2)
      travel 2.seconds
      model.step(3)
    end

    assert_equal 2, beats
  end

  it "beats right away once the heartbeat is reset" do
    beats = 0

    2.times { model.run(-> { beats += 1 }) { model.step(1) } }

    assert_equal 2, beats
  end

  it "stops the work when the heartbeat raises" do
    lost = -> { raise PublishingPipelineState::LostOwnershipError }

    assert_raises(PublishingPipelineState::LostOwnershipError) do
      model.run(lost) { model.step(1) { flunk "ran after losing ownership" } }
    end
  end
end
