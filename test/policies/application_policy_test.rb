require 'test_helper'

describe ApplicationPolicy do
  let(:token) { 'token' }
  let(:resource) { 'resource' }

  it 'prevents create' do
    ApplicationPolicy.new(token, resource).wont_allow :create?
  end

  it 'prevents update' do
    ApplicationPolicy.new(token, resource).wont_allow :update?
  end

  it 'prevents destroy' do
    ApplicationPolicy.new(token, resource).wont_allow :destroy?
  end
end
