require "test_helper"

describe PodcastPolicy do
  let(:account_id) { 123 }
  let(:podcast) { build_stubbed(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }

  def token(scopes, set_account_id = account_id)
    StubToken.new(set_account_id, scopes)
  end

  describe "#new?" do
    it "returns false if token is not present" do
      refute PodcastPolicy.new(nil, podcast).new?
    end

    it "returns true if you have any podcast create scopes" do
      refute PodcastPolicy.new(token("feeder:podcast-edit"), podcast).new?
      assert PodcastPolicy.new(token("feeder:podcast-create"), podcast).new?
    end
  end

  describe "#update?" do
    it "returns false if token is not present" do
      refute PodcastPolicy.new(nil, podcast).update?
    end

    it "returns false if token is not a member of the account" do
      refute PodcastPolicy.new(token("feeder:podcast-edit", account_id + 1), podcast).update?
    end

    it "returns true if token is a member of the account and has edit scope" do
      assert PodcastPolicy.new(token("feeder:podcast-edit"), podcast).update?
    end

    it "returns false if token lacks edit scope" do
      refute PodcastPolicy.new(token("feeder:podcast-create feeder:podcast-delete"), podcast).update?
    end

    it "disallows changing the account id of a podcast which the token did not previously have access to" do
      podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id + 1}")
      podcast.prx_account_uri = "/api/v1/accounts/#{account_id}"

      refute PodcastPolicy.new(token("feeder: podcast-edit"), podcast).update?
    end
  end

  describe "#create?" do
    it "returns false if token is not present" do
      refute PodcastPolicy.new(nil, podcast).create?
    end

    it "returns false if token is not a member of the account" do
      refute PodcastPolicy.new(token("feeder:podcast-create", account_id + 1), podcast).create?
    end

    it "returns true if token is a member of the account and has create scope" do
      assert PodcastPolicy.new(token("feeder:podcast-create"), podcast).create?
    end

    it "returns false if token lacks create scope" do
      refute PodcastPolicy.new(token("feeder:podcast-edit feeder:podcast-delete"), podcast).create?
    end
  end

  describe "#destroy?" do
    it "returns false if token is not present" do
      refute PodcastPolicy.new(nil, podcast).destroy?
    end

    it "returns false if token is not a member of the account" do
      refute PodcastPolicy.new(token("feeder:podcast-delete", account_id + 1), podcast).destroy?
    end

    it "returns true if token is a member of the account and has create scope" do
      assert PodcastPolicy.new(token("feeder:podcast-delete"), podcast).destroy?
    end

    it "returns false if token lacks destroy scope" do
      refute PodcastPolicy.new(token("feeder:podcast-create feeder:podcast-edit"), podcast).destroy?
    end

    it "returns false unless the podcast is new or has no published episodes" do
      podcast.created_at = 1.week.ago
      tok = token("feeder:podcast-delete")

      no_published = Struct.new(:none?).new(true)
      has_published = Struct.new(:none?).new(false)
      episodes = Struct.new(:published).new(no_published)

      podcast.stub(:episodes, episodes) do
        assert PodcastPolicy.new(tok, podcast).destroy?

        # with episodes, cannot destroy
        episodes.published = has_published
        refute PodcastPolicy.new(tok, podcast).destroy?

        # unless created very recently
        podcast.created_at = 1.hour.ago
        assert PodcastPolicy.new(tok, podcast).destroy?
      end
    end
  end

  describe "Scope" do
    let(:p1) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
    let(:p2) { create(:podcast, prx_account_uri: "/api/v1/accounts/456") }
    let(:query) { Podcast.where(id: [p1.id, p2.id]) }

    it "scopes queries" do
      podcasts = PodcastPolicy::Scope.new(token("feeder:read-private", 123), query).resolve
      assert_equal [p1], podcasts

      podcasts = PodcastPolicy::Scope.new(token("feeder:read-private", 456), query).resolve
      assert_equal [p2], podcasts

      podcasts = PodcastPolicy::Scope.new(token("feeder:nothing", 123), query).resolve
      assert_equal [], podcasts
    end
  end
end
