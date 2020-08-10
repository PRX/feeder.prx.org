require 'test_helper'

describe PodcastPolicy do
  let(:account_id) { 123 }
  let(:podcast) { build_stubbed(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}")}

  def token(scopes, set_account_id=account_id)
    StubToken.new(set_account_id, scopes)
  end

  describe '#update?' do
    it 'returns false if token is not present' do
      PodcastPolicy.new(nil, podcast).wont_allow :update?
    end

    it 'returns false if token is not a member of the account' do
      PodcastPolicy.new(token('feeder:podcast-edit', account_id + 1), podcast).wont_allow :update?
    end

    it 'returns true if token is a member of the account and has edit scope' do
      PodcastPolicy.new(token('feeder:podcast-edit'), podcast).must_allow :update?
    end

    it 'returns false if token lacks edit scope' do
      PodcastPolicy.new(token('feeder:podcast-create feeder:podcast-delete'), podcast).wont_allow :update?
    end
  end

  describe '#create?' do
    it 'returns false if token is not present' do
      PodcastPolicy.new(nil, podcast).wont_allow :create?
    end

    it 'returns false if token is not a member of the account' do
      PodcastPolicy.new(token('feeder:podcast-create', account_id + 1), podcast).wont_allow :create?
    end

    it 'returns true if token is a member of the account and has create scope' do
      PodcastPolicy.new(token('feeder:podcast-create'), podcast).must_allow :create?
    end

    it 'returns false if token lacks create scope' do
      PodcastPolicy.new(token('feeder:podcast-edit feeder:podcast-delete'), podcast).wont_allow :create?
    end
  end

  describe '#destroy?' do
    it 'returns false if token is not present' do
      PodcastPolicy.new(nil, podcast).wont_allow :destroy?
    end

    it 'returns false if token is not a member of the account' do
      PodcastPolicy.new(token('feeder:podcast-delete', account_id + 1), podcast).wont_allow :destroy?
    end

    it 'returns true if token is a member of the account and has create scope' do
      PodcastPolicy.new(token('feeder:podcast-delete'), podcast).must_allow :destroy?
    end

    it 'returns false if token lacks destroy scope' do
      PodcastPolicy.new(token('feeder:podcast-create feeder:podcast-edit'), podcast).wont_allow :destroy?
    end
  end
end
