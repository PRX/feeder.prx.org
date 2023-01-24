require "test_helper"

describe ApplicationPolicy do
  let(:token) { "token" }
  let(:resource) { "resource" }

  it "prevents create" do
    refute ApplicationPolicy.new(token, resource).create?
  end

  it "prevents update" do
    refute ApplicationPolicy.new(token, resource).update?
  end

  it "prevents destroy" do
    refute ApplicationPolicy.new(token, resource).destroy?
  end
end
