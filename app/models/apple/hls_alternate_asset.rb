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

    def self.for_key(episode:, binding:, feeder_guid:)
      find_by(feeder_podcast_id: episode.podcast_id, apple_show_id: binding.apple_show_id, feeder_guid: feeder_guid)
    end

    # Records the result of an Apple lookup or write for one asset key and
    # derives the local status. Pass the Apple resource that currently holds
    # the alternate-asset fields:
    #
    #   resource_type: :staged_alternate_asset, response: staged asset JSON
    #   resource_type: :episode, apple_episode: refreshed local Apple::Episode
    #   resource_type: nil, when Apple returned neither resource
    #
    # An error records the failure and keeps the last known Apple state.
    # Returns nil when Apple has nothing and there is no prior row (pending).
    def self.upsert_from_apple!(episode:, binding:, feeder_guid:, resource_type: nil, response: nil, apple_episode: nil, error: nil)
      if resource_type.present? && !RESOURCE_TYPES.include?(resource_type)
        raise ArgumentError, "unknown resource_type: #{resource_type.inspect}"
      end

      asset = for_key(episode: episode, binding: binding, feeder_guid: feeder_guid) ||
        new(feeder_podcast_id: episode.podcast_id, apple_show_id: binding.apple_show_id, feeder_guid: feeder_guid)
      return nil if asset.new_record? && resource_type.nil? && error.nil?

      asset.episode = episode
      asset.last_checked_at = Time.current

      if error
        asset.status = :error
        asset.last_error = error.respond_to?(:message) ? error.message : error.to_s
      elsif resource_type == :episode
        asset.status = :linked
        asset.content_url = apple_episode&.apple_json&.dig("attributes", "alternateAssetContentUrl") || asset.content_url
        asset.last_error = nil
      elsif resource_type == :staged_alternate_asset
        asset.status = :staged
        asset.staged_alternate_asset_id = response&.dig("id") || asset.staged_alternate_asset_id
        asset.content_url = response&.dig("attributes", "alternateAssetContentUrl") || asset.content_url
        asset.last_error = nil
      elsif asset.staged? || asset.expired?
        asset.status = :expired
        asset.last_error = nil
      else
        asset.status = :error
        asset.last_error = "Apple no longer reports the linked episode or a staged alternate asset"
      end

      asset.save!
      asset
    end
  end
end
