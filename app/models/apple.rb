module Apple
  # Duration thresholds for asset processing (in seconds)
  SLOW_EPISODE_THRESHOLD = 30.minutes.to_i
  STUCK_EPISODE_THRESHOLD = 1.hour.to_i

  def self.table_name_prefix
    "apple_"
  end
end
