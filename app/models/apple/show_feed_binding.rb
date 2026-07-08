# frozen_string_literal: true

module Apple
  class ShowFeedBinding < ApplicationRecord
    belongs_to :feed
    belongs_to :apple_key, class_name: "Apple::Key"

    has_many :delegated_delivery_configs,
      class_name: "Apple::Config",
      foreign_key: :show_feed_binding_id,
      inverse_of: :show_feed_binding,
      dependent: :nullify

    validates :apple_show_id, presence: true
    validates :feed_id, uniqueness: true
    validate :feed_must_be_public

    scope :active, -> { joins(:feed).where(feeds: {deleted_at: nil}) }

    def self.backfill_show_feed_bindings!(dry_run: false)
      report = new_backfill_report(dry_run: dry_run)

      Apple::Config.find_each do |config|
        report[:configs_total] += 1
        backfill_config!(config, report, dry_run: dry_run)
      end

      report
    end

    def self.verify_routing_equivalence!
      report = {configs_total: 0, mismatches: []}

      Apple::Config.find_each do |config|
        report[:configs_total] += 1
        binding = config.show_feed_binding

        unless binding
          report[:mismatches] << {
            config_id: config.id,
            reason: "missing binding"
          }
          next
        end

        public_feed = config.public_feed
        sync_log = SyncLog.apple.feeds.find_by(feeder_id: public_feed&.id)
        legacy_show_id = sync_log&.external_id.presence || config.private_feed&.apple_show_id.presence

        mismatch = {
          config_id: config.id,
          mismatches: []
        }

        if config[:key_id] != binding.apple_key_id
          mismatch[:mismatches] << {
            field: "apple_key_id",
            legacy: config[:key_id],
            binding: binding.apple_key_id
          }
        end

        if public_feed&.id != binding.feed_id
          mismatch[:mismatches] << {
            field: "feed_id",
            legacy: public_feed&.id,
            binding: binding.feed_id
          }
        end

        if legacy_show_id != binding.apple_show_id
          mismatch[:mismatches] << {
            field: "apple_show_id",
            legacy: legacy_show_id,
            binding: binding.apple_show_id
          }
        end

        report[:mismatches] << mismatch if mismatch[:mismatches].any?
      end

      report
    end

    def self.new_backfill_report(dry_run:)
      {
        dry_run: dry_run,
        configs_total: 0,
        created: 0,
        updated: 0,
        linked: 0,
        unchanged: 0,
        skipped: 0,
        changed: 0,
        actions: [],
        skipped_configs: []
      }
    end
    private_class_method :new_backfill_report

    def self.backfill_config!(config, report, dry_run:)
      key = config.key
      public_feed = config.public_feed
      legacy_show_id = legacy_apple_show_id(config, public_feed)

      return skip_config(config, report, "missing key") unless key
      return skip_config(config, report, "missing public feed") unless public_feed
      return skip_config(config, report, "missing show id") unless legacy_show_id.present?

      binding = find_or_initialize_by(feed: public_feed)
      binding_was_new = binding.new_record?
      needs_link = binding_was_new || config.show_feed_binding_id != binding.id
      changes = {}

      if binding_was_new
        changes[:create] = {
          feed_id: public_feed.id,
          apple_key_id: key.id,
          apple_show_id: legacy_show_id
        }
      else
        changes[:apple_key_id] = {from: binding.apple_key_id, to: key.id} if binding.apple_key_id != key.id
        changes[:apple_show_id] = {from: binding.apple_show_id, to: legacy_show_id} if binding.apple_show_id != legacy_show_id
      end

      if needs_link
        changes[:show_feed_binding_id] = {
          from: config.show_feed_binding_id,
          to: binding_was_new ? "new binding" : binding.id
        }
      end

      if changes.empty?
        report[:unchanged] += 1
        return report[:actions] << {config_id: config.id, action: "unchanged"}
      end

      action = binding_was_new ? "create" : "update"
      action = "link" if changes.keys == [:show_feed_binding_id]

      unless dry_run
        binding.apple_key = key
        binding.apple_show_id = legacy_show_id
        binding.save!

        if config.show_feed_binding_id != binding.id
          config.update!(show_feed_binding: binding)
        end
      end

      increment_backfill_counts(report, binding_was_new: binding_was_new, needs_link: needs_link, changes: changes)
      report[:actions] << {
        config_id: config.id,
        action: dry_run ? "would_#{action}" : action,
        feed_id: public_feed.id,
        binding_id: binding.id,
        changes: changes
      }
    end
    private_class_method :backfill_config!

    def self.legacy_apple_show_id(config, public_feed)
      sync_log = SyncLog.apple.feeds.find_by(feeder_id: public_feed&.id)
      sync_log&.external_id.presence || config.private_feed&.apple_show_id.presence
    end
    private_class_method :legacy_apple_show_id

    def self.skip_config(config, report, reason)
      report[:skipped] += 1
      report[:skipped_configs] << {config_id: config.id, reason: reason}
    end
    private_class_method :skip_config

    def self.increment_backfill_counts(report, binding_was_new:, needs_link:, changes:)
      if binding_was_new
        report[:created] += 1
      elsif (changes.keys - [:show_feed_binding_id]).any?
        report[:updated] += 1
      end

      report[:linked] += 1 if needs_link
      report[:changed] += 1
    end
    private_class_method :increment_backfill_counts

    def feed_must_be_public
      if feed && !feed.public?
        errors.add(:feed, "must be a public feed")
      end
    end
  end
end
