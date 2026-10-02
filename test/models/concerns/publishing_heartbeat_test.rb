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

      def call_guarded(other)
        other.guarded
      end

      protected

      def guarded
        :guarded
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

  it "beats on entry and forwards arguments and blocks" do
    beats = 0
    result = model.run(-> { beats += 1 }) { model.step(1, key: 2) { 3 } }

    assert_equal [1, 2, 3], result
    assert_equal 1, beats
  end

  it "preserves private and protected visibility" do
    assert_raises(NoMethodError) { model.helper }
    assert_raises(NoMethodError) { model.guarded }
    assert_equal :helper, model.send(:helper)
    assert_equal :guarded, model.call_guarded(klass.new)
  end

  it "only wraps methods defined before heartbeat_around_all_methods" do
    beats = 0

    model.run(-> { beats += 1 }) { model.defined_after }

    assert_equal 0, beats
  end

  it "throttles beats until the interval passes or the heartbeat is reset" do
    beats = 0
    heartbeat = -> { beats += 1 }

    model.run(heartbeat) do
      model.step(1)
      assert_equal 1, beats
      model.send(:helper)
      travel PublishingHeartbeat::HEARTBEAT_INTERVAL - 1.second
      model.step(2)
      assert_equal 1, beats
      travel 2.seconds
      model.step(3)
    end

    assert_equal 2, beats
    model.run(heartbeat) { model.step(1) }
    assert_equal 3, beats
  end

  it "stops the work when the heartbeat raises" do
    lost = -> { raise PublishingPipelineState::LostOwnershipError }

    assert_raises(PublishingPipelineState::LostOwnershipError) do
      model.run(lost) { model.step(1) { flunk "ran after losing ownership" } }
    end
  end
end
