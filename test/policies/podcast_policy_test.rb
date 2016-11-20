require 'test_helper'

describe PodcastPolicy do
  let(:account_id) { 123 }
  let(:non_member_token) { StubToken.new(account_id + 1, ['no']) }
  let(:member_token) { StubToken.new(account_id, ['member']) }
  let(:podcast) { build_stubbed(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}")}

  describe '#update?' do
    it 'returns false if token is not present' do
      PodcastPolicy.new(nil, podcast).wont_allow :update?
    end

    it 'returns false if token is not a member of the account' do
      PodcastPolicy.new(non_member_token, podcast).wont_allow :update?
    end

    it 'returns true if token is a member of the account' do
      PodcastPolicy.new(member_token, podcast).must_allow :update?
    end
  end
end
