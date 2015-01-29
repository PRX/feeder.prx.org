require 'test_helper'

describe DateUpdater do
  before do
    Timecop.freeze(Time.local(2015, 1, 13))

    @podcast = create(:podcast)
    @pd = @podcast.pub_date
  end

  after do
    Timecop.return
  end

  describe '#both_dates' do
    it 'updates both date attributes' do
      DateUpdater.both_dates(@podcast)

      @podcast.reload

      @podcast.last_build_date.must_equal Time.now
      @podcast.pub_date.must_equal Time.now
    end
  end

  describe '#last_build_date' do
    it 'only updates the last build date' do
      DateUpdater.last_build_date(@podcast)

      @podcast.reload

      @podcast.last_build_date.must_equal Time.now
      @podcast.pub_date.must_equal @pd
    end
  end
end
