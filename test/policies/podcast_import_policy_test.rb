require "test_helper"

describe PodcastImportPolicy do
  let(:account) { build_stubbed(:account, id: 1234) }
  let(:import) { build(:podcast_import, account: account) }

  def policy(scope)
    PodcastImportPolicy.new(StubToken.new(account.id, scope), import)
  end

  it "requires both story and series scopes" do
    policy("cms:series cms:story").must_allow :create?
    policy("cms:series cms:story").must_allow :update?

    policy("cms:story").wont_allow :create?
    policy("cms:series").wont_allow :create?
  end
end
