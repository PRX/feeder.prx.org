# frozen_string_literal: true

require 'test_helper'

describe Apple::Show do

  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast) }
  let(:apple_show) { Apple::Show.new(feed) }

  describe '#sync!' do
    it 'runs sync!' do

      apple_show.stub(:create_or_update_show, nil) do
        sync = apple_show.sync!

        assert_equal sync.class, SyncLog
      end
    end
  end

  describe '#show_data' do
    it 'returns a hash' do
      assert_equal apple_show.show_data.class, Hash
    end
  end
end
