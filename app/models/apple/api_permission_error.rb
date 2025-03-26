module Apple
  class ApiPermissionError < Apple::ApiError
    MAX_BACKOFF_MINUTES = 480 # 8 hours
    DEFAULT_CACHE_TTL = 24.hours

    def log_level(feed)
      raise_publishing_error?(feed) ? :error : :warn
    end

    def cache_key(feed)
      "apple_permission_error:#{feed.id}"
    end

    def raise_publishing_error?(feed)
      error_state = Rails.cache.fetch(cache_key(feed), expires_in: DEFAULT_CACHE_TTL) { {count: 1, last_logged: Time.now.utc} }
      count = error_state[:count]
      last_logged = error_state[:last_logged]
      now = Time.now.utc

      # Calculate backoff minutes using exponential formula: 15 * 2^(n-1)
      # Starting at 15 minutes, then 30, 60, 120... minutes
      # Cap at 8 hours (480 minutes)
      backoff_minutes = [15 * (2**(count - 1)), MAX_BACKOFF_MINUTES].min

      # Only log if we're past the backoff window
      if last_logged < (now - backoff_minutes.minutes)
        error_state[:count] += 1
        error_state[:last_logged] = now
        # Store updated count
        Rails.cache.write(cache_key, error_state, expires_in: DEFAULT_CACHE_TTL)
        true
      else
        false
      end
    end
  end
end
