# frozen_string_literal: true

module Apple
  # Local mirror of one Apple alternate-asset lifecycle, keyed by the Apple
  # show and the rendered RSS GUID. Apple remains the source of truth; this
  # row caches the latest known state for status reads and recovery.
  class HlsAlternateAsset < ApplicationRecord
    CONTENT_KIND = "VIDEO"
    MIME_TYPE = "application/vnd.apple.mpegurl"
    RESOURCE_TYPES = %i[staged_alternate_asset episode].freeze

    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"
    belongs_to :feeder_podcast, class_name: "::Podcast"

    enum :status, {staged: 0, linked: 1, expired: 2, error: 3}

    validates :apple_show_id, :feeder_guid, :status, presence: true
    validates :feeder_guid, uniqueness: {scope: [:feeder_podcast_id, :apple_show_id]}

    # Records the result of an Apple lookup or write for one asset key and
    # derives the local status. Pass the JSON of the Apple resource that
    # currently holds the alternate-asset fields:
    #
    #   resource_type: :staged_alternate_asset, response: staged asset JSON
    #   resource_type: :episode, response: Apple episode JSON
    #   resource_type: nil, when Apple returned neither resource
    #
    # An error records the failure and keeps the last known Apple state.
    # Returns nil when Apple has neither resource and there is no prior row
    # (pending).
    def self.upsert_from_apple!(episode:, show_feed_binding:, feeder_guid:, resource_type: nil, response: nil, error: nil)
      if resource_type && !RESOURCE_TYPES.include?(resource_type)
        raise ArgumentError, "unknown resource_type: #{resource_type.inspect}"
      end

      key = {feeder_podcast_id: episode.podcast_id, apple_show_id: show_feed_binding.apple_show_id, feeder_guid: feeder_guid}
      asset = find_by(key)
      return nil if asset.nil? && resource_type.nil? && error.nil?

      asset ||= new(key)
      asset.episode = episode
      asset.last_checked_at = Time.current

      if error
        asset.status = :error
        asset.last_error = error.respond_to?(:message) ? error.message : error.to_s
      elsif resource_type == :episode
        asset.status = :linked
        asset.apple_episode_id = response&.dig("id") || asset.apple_episode_id
        asset.content_url = response&.dig("attributes", "alternateAssetContentUrl") || asset.content_url
        asset.last_error = nil
      elsif resource_type == :staged_alternate_asset
        asset.status = :staged
        asset.staged_alternate_asset_id = response&.dig("id") || asset.staged_alternate_asset_id
        asset.content_url = response&.dig("attributes", "alternateAssetContentUrl") || asset.content_url
        asset.last_error = nil
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
  end
end
