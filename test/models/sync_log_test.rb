require 'test_helper'
require 'prx_access'

describe SyncLog do

  describe '.podcasts' do
    it 'filters records by a podcast enum' do
      s = SyncLog.new(feeder_type: 'p', feeder_id: 123)
      s.save!
      assert_equal SyncLog.podcasts, [s]
    end
  end
end
