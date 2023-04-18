# frozen_string_literal: true

require 'test_helper'
require 'cms_syncher'

describe CmsSyncher do
  let(:user_id) { 123 }
  let(:episode) { create(:episode) }
  let(:podcast) { create(:podcast) }

  it 'synchs a cms series to a podcast' do
    refute_nil podcast
  end

  it 'synchs a cms story to an episode' do
    refute_nil episode
  end
end
