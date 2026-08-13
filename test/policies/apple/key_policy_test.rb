require "test_helper"

describe Apple::KeyPolicy do
  let(:account_id) { 123 }
  let(:key) { build_stubbed(:apple_key, account_id: account_id) }

  def token(scopes, authorized_account_id = account_id)
    StubToken.new(authorized_account_id, scopes)
  end

  it "authorizes reads in the key account" do
    assert Apple::KeyPolicy.new(token("feeder:read-private"), key).show?
    refute Apple::KeyPolicy.new(token("feeder:read-private", 456), key).show?
  end

  it "authorizes writes in the key account" do
    assert Apple::KeyPolicy.new(token("feeder:podcast-edit"), key).create?
    assert Apple::KeyPolicy.new(token("feeder:podcast-edit"), key).update?
    refute Apple::KeyPolicy.new(token("feeder:read-private"), key).create?
  end

  it "scopes keys to readable accounts" do
    readable = create(:apple_key, account_id: 123)
    create(:apple_key, account_id: 456)

    result = Apple::KeyPolicy::Scope.new(token("feeder:read-private"), Apple::Key.all).resolve

    assert_equal [readable], result
  end
end
