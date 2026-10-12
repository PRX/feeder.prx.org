# frozen_string_literal: true

module Apple
  class HlsAlternateAsset < ApplicationRecord
    CONTENT_KIND = "VIDEO"
    MIME_TYPE = "application/vnd.apple.mpegurl"
    RESOURCE_TYPES = %i[staged_alternate_asset episode].freeze

    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"
    belongs_to :feeder_podcast, class_name: "::Podcast"

    enum :status, {staged: 0, linked: 1, expired: 2, error: 3}

    validates :apple_show_id, :feeder_guid, :status, presence: true
    validates :feeder_guid, uniqueness: {scope: [:feeder_podcast_id, :apple_show_id]}

    # Records the status of remote Apple resource state.
    # Takes in the JSON of the Apple resource that currently holds the
    # alternate-asset fields:
    #
    #   resource_type: :staged_alternate_asset, response: staged asset JSON
    #   resource_type: :episode, response: Apple episode JSON
    #   resource_type: nil, when Apple returned neither resource
    #
    def self.upsert_from_apple!(episode:, show_feed_binding:, feeder_guid:, resource_type: nil, response: nil, error: nil, unless_checked_after: nil)
      if resource_type && !RESOURCE_TYPES.include?(resource_type)
        raise ArgumentError, "unknown resource_type: #{resource_type.inspect}"
      end

      key = {feeder_podcast_id: episode.podcast_id, apple_show_id: show_feed_binding.apple_show_id, feeder_guid: feeder_guid}
      asset = find_by(key)
      return asset if unless_checked_after && asset&.last_checked_at&.after?(unless_checked_after)
      return nil if asset.nil? && resource_type.nil? && error.nil?

      asset ||= new(key)
      asset.episode = episode
      asset.last_checked_at = Time.current

      if error
        asset.status = :error
        asset.last_error = error.respond_to?(:message) ? error.message : error.to_s
      elsif resource_type
        content_url = response&.dig("attributes", "alternateAssetContentUrl").presence
        if resource_type == :episode
          asset.apple_episode_id = response&.dig("id") || asset.apple_episode_id
          asset.content_url = content_url
        else
          asset.staged_alternate_asset_id = response&.dig("id") || asset.staged_alternate_asset_id
          asset.content_url = content_url || asset.content_url
        end

        if (outdated = outdated_error(response, episode, show_feed_binding))
          asset.status = :error
          asset.last_error = outdated
        elsif resource_type == :staged_alternate_asset
          asset.status = :staged
          asset.last_error = nil
        elsif content_url
          # Apple can hold the episode without its video (crawled before
          # staging, or the staged asset expired), so only a content URL links.
          asset.status = :linked
          asset.last_error = nil
        else
          asset.status = :error
          asset.last_error = "Apple reports the episode without an alternate asset"
        end
      # We have no remote apple episode or alternate asset, but we have local state
      elsif asset.staged? || asset.expired?
        asset.status = :expired
        asset.last_error = nil
      elsif asset.linked?
        asset.status = :error
        asset.last_error = "Apple no longer reports the linked episode or a staged alternate asset"
      end

      asset.save!
      asset
    end

    def self.apple_attributes(url)
      {
        alternateAssetContentUrl: url,
        alternateAssetContentKind: CONTENT_KIND,
        alternateAssetMimeType: MIME_TYPE
      }
    end

    # Whether an Apple episode or staged asset JSON holds the expected URL,
    # content kind, and MIME type.
    def self.current_on_apple?(response, url)
      attributes = response&.dig("attributes") || {}
      apple_attributes(url).all? { |key, value| attributes[key.to_s] == value }
    end

    def self.outdated_error(response, episode, show_feed_binding)
      content_url = response&.dig("attributes", "alternateAssetContentUrl")
      return if content_url.blank?

      expected_url = episode.apple_hls_master_url(feed: show_feed_binding.feed)
      return if expected_url.blank? || current_on_apple?(response, expected_url)

      if content_url == expected_url
        "Apple has an outdated alternate asset content kind or MIME type"
      else
        "Apple has an outdated alternate asset URL"
      end
    end
    private_class_method :outdated_error
  end
end
