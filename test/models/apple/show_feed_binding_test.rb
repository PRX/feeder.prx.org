require "test_helper"

module Apple
  describe ShowFeedBinding do
    describe "validations" do
      it "requires an apple show id" do
        binding = build(:apple_show_feed_binding, apple_show_id: nil)

        refute binding.valid?
        assert_includes binding.errors[:apple_show_id], "Can't be blank"
      end

      it "requires a public feed" do
        private_feed = create(:private_feed, podcast: create(:podcast))
        binding = build(:apple_show_feed_binding, feed: private_feed)

        refute binding.valid?
        assert_includes binding.errors[:feed], "must be a public feed"
      end

      it "allows only one binding per feed" do
        feed = create(:public_feed, podcast: create(:podcast))
        create(:apple_show_feed_binding, feed: feed)

        binding = build(:apple_show_feed_binding, feed: feed)

        refute binding.valid?
        assert_includes binding.errors[:feed_id], "has already been taken"
      end
    end

    describe ".active" do
      it "excludes bindings whose feeds are soft deleted" do
        binding = create(:apple_show_feed_binding)
        active_binding = create(:apple_show_feed_binding)

        Feed.where(id: binding.feed_id).update_all(deleted_at: Time.current)

        assert_includes ShowFeedBinding.active.to_a, active_binding
        refute_includes ShowFeedBinding.active.to_a, binding
      end
    end
  end
end
