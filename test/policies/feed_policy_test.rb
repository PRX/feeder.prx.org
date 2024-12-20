require "test_helper"

describe FeedPolicy do
  let(:account_id) { 123 }
  let(:non_member_token) { StubToken.new(account_id + 1, ["podcast_edit"]) }
  let(:member_token) { StubToken.new(account_id, ["podcast_edit"]) }
  let(:podcast) { build_stubbed(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:feed) { build_stubbed(:feed, podcast: podcast) }

  describe "#update?" do
    it "returns false if token is not present" do
      refute FeedPolicy.new(nil, feed).update?
    end

    it "returns false if token is not a member of the account" do
      refute FeedPolicy.new(non_member_token, feed).update?
    end

    it "returns true if token is a member of the account" do
      assert FeedPolicy.new(member_token, feed).update?
    end

    it "returns false if the feed is edit_locked" do
      feed.edit_locked = true
      refute FeedPolicy.new(member_token, feed).update?
    end
  end

  describe "#destroy?" do
    it "will not destroy the default feed" do
      refute feed.default?
      assert FeedPolicy.new(member_token, feed).destroy?

      feed.slug = nil
      refute FeedPolicy.new(member_token, feed).destroy?
    end
  end
end
