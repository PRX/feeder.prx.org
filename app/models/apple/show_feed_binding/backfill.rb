# frozen_string_literal: true

module Apple
  class ShowFeedBinding
    # Transitional migration service: extracts Apple show/key/feed routing out
    # of legacy apple_configs, feeds.apple_show_id, and public-feed SyncLog
    # rows into Apple::ShowFeedBinding. Run by hand in the production console
    # (dry-run, backfill, verify). Delete once legacy routing columns are gone.
    class Backfill
      def self.backfill!(dry_run: false)
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

      # Precondition for show-scoping legacy Apple episode SyncLogs: every
      # stored Apple episode id must still belong to the podcast's bound show.
      # Run after the binding backfill and resolve any mismatch before deploying
      # show-scoped episode identity.
      def self.verify_episode_show_consistency!
        report = {
          configs_total: 0,
          episode_sync_logs_total: 0,
          mismatches: [],
          errors: []
        }

        Apple::Config.find_each do |config|
          report[:configs_total] += 1
          verify_config_episode_show_consistency!(config, report)
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

        binding = Apple::ShowFeedBinding.find_or_initialize_by(feed: public_feed)
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

      def self.verify_config_episode_show_consistency!(config, report)
        binding = config.show_feed_binding
        unless binding
          report[:errors] << {config_id: config.id, reason: "missing binding"}
          return
        end

        show = config.build_show
        remote_episode_ids = Apple::Show
          .apple_episode_json(show.api, binding.apple_show_id)
          .to_h { |episode_json| [episode_json.fetch("id").to_s, true] }

        episode_ids = ::Episode.with_deleted
          .where(podcast_id: config.podcast.id)
          .select(:id)

        SyncLog.apple.episodes.where(feeder_id: episode_ids).find_each do |sync_log|
          report[:episode_sync_logs_total] += 1
          next if remote_episode_ids.key?(sync_log.external_id.to_s)

          report[:mismatches] << {
            config_id: config.id,
            apple_show_id: binding.apple_show_id,
            sync_log_id: sync_log.id,
            feeder_id: sync_log.feeder_id,
            external_id: sync_log.external_id
          }
        end
      rescue => e
        report[:errors] << {
          config_id: config.id,
          apple_show_id: binding&.apple_show_id,
          reason: "Apple show episode verification failed: #{e.class}: #{e.message}"
        }
      end
      private_class_method :verify_config_episode_show_consistency!

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
    end
  end
end
