# frozen_string_literal: true

module Apple
  class HlsConfig < ApplicationRecord
    belongs_to :show_feed_binding, class_name: "Apple::ShowFeedBinding", inverse_of: :hls_config

    validates :show_feed_binding_id, uniqueness: true

    def self.video_enabled?(show_response)
      show_response&.dig("data", "attributes", "alternateAssetVideoEnabled") == true
    end

    # Enabled, but Apple has not enabled video for the show.
    def not_eligible?
      enabled? && !video_enabled_cache
    end

    # Enabled and Apple accepts video for the show.
    def publishable?
      enabled? && video_enabled_cache == true
    end

    def refresh_eligibility
      apple_key = show_feed_binding.feed.podcast.apple_key
      raise "Missing Apple key for podcast" unless apple_key

      api = Apple::Api.from_key(apple_key)
      show_response = Apple::Show.get_show(api, show_feed_binding.apple_show_id)
      self.video_enabled_cache = self.class.video_enabled?(show_response)
      self.last_checked_at = Time.current
      video_enabled_cache
    end

    def refresh_eligibility!
      refresh_eligibility
      save!
      video_enabled_cache
    end
  end
end
