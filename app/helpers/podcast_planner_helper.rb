module PodcastPlannerHelper
  RECURRING_WEEKS = ["Every week", "Every two weeks", "Every three weeks", "Every four weeks"]
  NUMBERED_WEEKS = ["First week", "Second week", "Third week", "Fourth week", "Fifth week"]

  def recurring_weeks_options
    RECURRING_WEEKS
  end

  def numbered_weeks_options
    NUMBERED_WEEKS
  end
end
