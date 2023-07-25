require "test_helper"

describe PodcastImportPolicy do
  let(:podcast_url) { "http://feeds.prx.org/transistor_stem" }
  let(:podcast) { create(:podcast) }
  let(:podcast_import) { create(:podcast_import, podcast: podcast) }
  let(:import) { PodcastImport.create(podcast: podcast, account_id: account_id, url: podcast_url) }
  let(:account_id) { podcast.prx_account_uri.split("/").last.to_i }

  def token(scopes, set_account_id = account_id)
    StubToken.new(set_account_id, scopes)
  end

  describe "#new?" do
    it "returns false if token is not present" do
      refute PodcastImportPolicy.new(nil, podcast_import).new?
    end

    it "returns true if you have any podcast create scopes" do
      refute PodcastImportPolicy.new(token("feeder:podcast-edit"), podcast_import).new?
      assert PodcastImportPolicy.new(token("feeder:podcast-create"), podcast_import).new?
    end
  end

  describe "#update?" do
    it "returns false if token is not present" do
      refute PodcastImportPolicy.new(nil, podcast_import).update?
    end

    it "returns false if token is not a member of the account" do
      refute PodcastImportPolicy.new(token("feeder:podcast-edit", account_id + 1), podcast_import).update?
    end

    it "returns true if token is a member of the account and has edit scope" do
      assert PodcastImportPolicy.new(token("feeder:podcast-edit"), podcast_import).update?
    end

    it "returns false if token lacks edit scope" do
      refute PodcastImportPolicy.new(token("feeder:podcast-create feeder:podcast-delete"), podcast_import).update?
    end
  end

  describe "#create?" do
    it "returns false if token is not present" do
      refute PodcastImportPolicy.new(nil, podcast_import).create?
    end

    it "returns false if token is not a member of the account" do
      refute PodcastImportPolicy.new(token("feeder:podcast-edit", account_id + 1), podcast_import).create?
    end

    it "returns true if token is a member of the account and has edit scope" do
      assert PodcastImportPolicy.new(token("feeder:podcast-edit"), podcast_import).create?
    end

    it "returns false if token lacks edit scope" do
      refute PodcastImportPolicy.new(token("feeder:read-private"), podcast_import).create?
    end
  end

  describe "#destroy?" do
    it "returns false if token is not present" do
      refute PodcastImportPolicy.new(nil, podcast_import).destroy?
    end

    it "returns false if token is not a member of the account" do
      refute PodcastImportPolicy.new(token("feeder:podcast-delete", account_id + 1), podcast_import).destroy?
    end

    it "returns true if token is a member of the account and has create scope" do
      assert PodcastImportPolicy.new(token("feeder:podcast-delete"), podcast_import).destroy?
    end

    it "returns false if token lacks destroy scope" do
      refute PodcastImportPolicy.new(token("feeder:podcast-create feeder:podcast-edit"), podcast_import).destroy?
    end
  end

  describe "Scope" do
    let(:p1) { create(:podcast, prx_account_uri: "/api/v1/accounts/123") }
    let(:p2) { create(:podcast, prx_account_uri: "/api/v1/accounts/456") }
    let(:import1) { create(:podcast_import, podcast: p1) }
    let(:import2) { create(:podcast_import, podcast: p2) }

    let(:query) { PodcastImport.all }

    it "scopes queries" do
      assert_equal [import1, import2], query.reset
      podcast_imports = PodcastImportPolicy::Scope.new(token("feeder:read-private", 123), query).resolve
      assert_equal [import1], podcast_imports

      podcast_imports = PodcastImportPolicy::Scope.new(token("feeder:read-private", 456), query).resolve
      assert_equal [import2], podcast_imports

      podcast_imports = PodcastImportPolicy::Scope.new(token("feeder:nothing", 123), query).resolve
      assert_equal [], podcast_imports
    end
  end
end
