require 'test_helper'

describe EpisodePolicy do
  let(:account_id) { 123 }
  let(:podcast) { build_stubbed(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}")}
  let(:episode) { build_stubbed(:episode, podcast: podcast)}

  def token(scopes, set_account_id=account_id)
    StubToken.new(set_account_id, scopes)
  end

  describe '#update? and #create?' do
    it 'returns false if token is not present' do
      EpisodePolicy.new(nil, episode).wont_allow :update?
    end

    it 'returns false if token is not a member of the account' do
      EpisodePolicy.new(token('feeder:episode', account_id + 1), episode).wont_allow :update?
      EpisodePolicy.new(token('feeder:episode', account_id + 1), episode).wont_allow :create?
    end

    it 'returns true if token is a member of the account' do
      EpisodePolicy.new(token('feeder:episode'), episode).must_allow :update?
      EpisodePolicy.new(token('feeder:episode'), episode).must_allow :create?
    end

    it 'returns false if the token lacks the episode scope' do
      EpisodePolicy.new(token('feeder:read-private'), episode).wont_allow :update?
      EpisodePolicy.new(token('feeder:read-private'), episode).wont_allow :create?
    end

    it 'returns false if changing podcast from one the token has no access to' do
      episode = create(:episode, podcast: create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id + 1}"))
      episode.podcast = podcast

      refute EpisodePolicy.new(token('feeder:episode'), episode).update?
    end
  end

  describe 'with a draft only token' do
    let (:draft_token) { token('feeder:episode-draft') }

    it 'allows creating a new draft epsiode' do
      episode = build(:episode, published_at: nil, podcast: build(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}"))
      assert EpisodePolicy.new(draft_token, episode).create?
    end

    it 'allows editing an existing draft episode' do
      episode = create(:episode, published_at: nil, podcast: podcast)

      episode.title = 'changed!'
      assert EpisodePolicy.new(draft_token, episode).update?
    end

    it 'does not allow creating a non-draft episode' do
      episode.published_at = 2.days.ago

      refute EpisodePolicy.new(draft_token, episode).create?
    end

    it 'does not allow editing a published episode (even to make it a draft)' do
      episode = create(:episode, published_at: 5.days.from_now, podcast: create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}"))

      episode.published_at = nil
      refute EpisodePolicy.new(draft_token, episode).update?
    end
  end
end
