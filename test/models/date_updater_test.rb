require 'test_helper'

describe DateUpdater do
  before do
    @podcast = create(:podcast)
    @pd = @podcast.pub_date
    @now = DateTime.parse('Jan 13, 2015')
  end

  describe '#both_dates' do
    it 'updates both date attributes' do
      Time.stub(:now, @now) do
        DateUpdater.both_dates(@podcast)
      end

      @podcast.reload

      @podcast.last_build_date.must_equal @now
      @podcast.pub_date.must_equal @now
    end
  end

  describe '#last_build_date' do
    it 'only updates the last build date' do
      Time.stub(:now, @now) do
        DateUpdater.last_build_date(@podcast)
      end

      @podcast.reload

      @podcast.last_build_date.must_equal @now
      @podcast.pub_date.wont_equal @now
    end
  end
end
