require 'test_helper'

describe EpisodePolicy do
  let(:account_id) { 123 }
  let(:non_member_token) { StubToken.new(account_id + 1, ['no']) }
  let(:member_token) { StubToken.new(account_id, ['member']) }
  let(:podcast) { build_stubbed(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}")}
  let(:episode) { build_stubbed(:episode, podcast: podcast)}

  describe '#update?' do
    it 'returns false if token is not present' do
      EpisodePolicy.new(nil, episode).wont_allow :update?
    end

    it 'returns false if token is not a member of the account' do
      EpisodePolicy.new(non_member_token, episode).wont_allow :update?
    end

    it 'returns true if token is a member of the account' do
      EpisodePolicy.new(member_token, episode).must_allow :update?
    end
  end
end
