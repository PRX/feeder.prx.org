require "test_helper"

describe LocationPolicy do
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast) }
  let(:account_id) { podcast.prx_account_uri.split("/").last.to_i }

  def token(scopes, set_account_id = account_id)
    StubToken.new(set_account_id, scopes)
  end

  describe "for podcast locations" do
    let(:loc) { build(:location, owner: podcast) }

    it "delegates to the podcast policy" do
      assert LocationPolicy.new(token("feeder:podcast-edit"), loc).update?
      assert LocationPolicy.new(token("feeder:podcast-edit"), loc).create?
      assert LocationPolicy.new(token("feeder:podcast-edit"), loc).destroy?

      refute LocationPolicy.new(token("feeder:podcast-edit", account_id + 1), loc).update?
      refute LocationPolicy.new(token("feeder:read-private"), loc).update?
      refute LocationPolicy.new(nil, loc).update?
    end
  end

  describe "for episode locations" do
    let(:loc) { build(:location, owner: episode) }

    it "delegates to the episode policy" do
      assert LocationPolicy.new(token("feeder:episode"), loc).update?
      assert LocationPolicy.new(token("feeder:episode"), loc).create?
      assert LocationPolicy.new(token("feeder:episode"), loc).destroy?

      refute LocationPolicy.new(token("feeder:episode", account_id + 1), loc).update?
      refute LocationPolicy.new(token("feeder:read-private"), loc).update?
      refute LocationPolicy.new(nil, loc).update?
    end
  end
end
