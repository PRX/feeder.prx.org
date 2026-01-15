module Apple
  # As of 2026-01-07 asset processing percentiles:
  # p50 11 minutes, p95 ~20 minutes, p99 ~33 minutes

  # Duration thresholds for asset processing (in seconds)
  SLOW_EPISODE_THRESHOLD = 20.minutes.to_i
  STUCK_EPISODE_THRESHOLD = 35.minutes.to_i

  def self.table_name_prefix
    "apple_"
  end
end
