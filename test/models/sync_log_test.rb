require 'test_helper'
require 'prx_access'

describe SyncLog do

  describe '.feeds' do
    it 'filters records by a feeds enum' do
      s = SyncLog.new(feeder_type: 'f', feeder_id: 123)
      s.save!
      assert_equal SyncLog.feeds, [s]
    end
  end
end
