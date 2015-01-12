class DateUpdater
  def initialize(podcast)
    @podcast = podcast
    @now = Time.now
  end

  def both_dates
    last_build_date
    @podcast.update_column(:pub_date, @now)
  end

  def last_build_date
    @podcast.update_column(:last_build_date, @now)
  end

  def self.both_dates(podcast)
    new(podcast).both_dates
  end

  def self.last_build_date(podcast)
    new(podcast).last_build_date
  end
end
