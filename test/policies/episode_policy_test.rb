require 'test_helper'

describe EpisodePolicy do
  let(:account_id) { 123 }
  let(:podcast) { build_stubbed(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}")}
  let(:episode) { build_stubbed(:episode, podcast: podcast)}

  def token(scopes, set_account_id=account_id)
    StubToken.new(set_account_id, scopes)
  end

  describe '#update?' do
    it 'returns false if token is not present' do
      EpisodePolicy.new(nil, episode).wont_allow :update?
    end

    it 'returns false if token is not a member of the account' do
      EpisodePolicy.new(token('feeder:episode', account_id + 1), episode).wont_allow :update?
    end

    it 'returns true if token is a member of the account' do
      EpisodePolicy.new(token('feeder:episode'), episode).must_allow :update?
    end
  end
end
