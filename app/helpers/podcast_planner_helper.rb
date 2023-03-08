module PodcastPlannerHelper
  RECURRING_WEEKS = ["Every week", "Every two weeks", "Every three weeks", "Every four weeks"]
  NUMBERED_WEEKS = ["First week of the month", "Second week of the month", "Third week of the month", "Fourth week of the month", "Fifth week of the month"]

  def recurring_weeks_options
    RECURRING_WEEKS
  end

  def numbered_weeks_options
    NUMBERED_WEEKS
  end

  def end_condition_options
    [["number of episodes", 0], ["end date", 1]]
  end

  def week_condition_options
    [["periodic", 0], ["monthly", 1]]
  end

  def episode_publish_time_options
    [Time.new("12:00"), Time.new("12:30")]
  end
end
