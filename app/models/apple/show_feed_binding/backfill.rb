# frozen_string_literal: true

module Apple
  class ShowFeedBinding
    # Transitional migration service: selects each podcast's legacy Apple key
    # and extracts show/feed routing into Apple::ShowFeedBinding. Run by hand in
    # the production console (dry-run, backfill, verify). Delete once legacy
    # routing columns are gone.
    class Backfill
      def self.backfill!(dry_run: false)
        report = new_backfill_report(dry_run: dry_run)
        configs = Apple::Config.includes(:key, feed: :podcast).to_a
        report[:configs_total] = configs.length
        report[:binding_conflicts] = binding_conflicts_for(configs)
        conflicting_config_ids = report[:binding_conflicts].flat_map { |conflict| conflict[:config_ids] }.uniq

        configs.group_by { |config| config.podcast&.id }.each_value do |podcast_configs|
          if podcast_configs.filter_map { |config| config[:key_id] }.uniq.many?
            backfill_podcast_key!(podcast_configs, report, dry_run: dry_run)
            next
          end

          conflicting_configs, eligible_configs = podcast_configs.partition do |config|
            conflicting_config_ids.include?(config.id)
          end
          conflicting_configs.each do |config|
            skip_config(config, report, "show feed binding claimed by multiple configs")
          end

          next if eligible_configs.empty?
          next unless backfill_podcast_key!(eligible_configs, report, dry_run: dry_run)

          eligible_configs.each do |config|
            backfill_config!(config, report, dry_run: dry_run)
          end
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

          if config[:key_id] != config.podcast&.apple_key_id
            mismatch[:mismatches] << {
              field: "podcast.apple_key_id",
              legacy: config[:key_id],
              podcast: config.podcast&.apple_key_id
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
          skipped_configs: [],
          podcast_keys_assigned: 0,
          key_actions: [],
          key_conflicts: []
        }
      end
      private_class_method :new_backfill_report

      def self.binding_conflicts_for(configs)
        configs
          .filter_map { |config| [config.public_feed&.id, config.id] if config.public_feed }
          .group_by(&:first)
          .filter_map do |feed_id, claims|
            binding = Apple::ShowFeedBinding.find_by(feed_id: feed_id)
            assigned_config_ids = if binding
              Apple::Config.where(show_feed_binding_id: binding.id).pluck(:id)
            else
              []
            end
            config_ids = (claims.map(&:last) + assigned_config_ids).uniq.sort
            next unless config_ids.many?

            {
              feed_id: feed_id,
              binding_id: binding&.id,
              config_ids: config_ids
            }
          end
      end
      private_class_method :binding_conflicts_for

      def self.backfill_podcast_key!(configs, report, dry_run:)
        podcast = configs.first&.podcast
        unless podcast
          configs.each { |config| skip_config(config, report, "missing podcast") }
          return
        end

        keys = configs.filter_map(&:key)
        if keys.empty?
          configs.each { |config| skip_config(config, report, "missing key") }
          return
        end

        key_ids = keys.map(&:id).uniq
        if key_ids.many?
          conflict = {
            podcast_id: podcast.id,
            config_ids: configs.map(&:id),
            key_ids: key_ids.sort
          }
          report[:key_conflicts] << conflict
          configs.each { |config| skip_config(config, report, "conflicting keys") }
          return
        end

        key = keys.first

        changes = {
          podcast_apple_key_id: {from: podcast.apple_key_id, to: key.id},
          config_ids: configs.select { |config| config[:key_id] != key.id }.map(&:id)
        }
        assigns_podcast_key = changes[:podcast_apple_key_id][:from] != changes[:podcast_apple_key_id][:to]
        changes_key_route = assigns_podcast_key || changes[:config_ids].any?

        unless dry_run
          configs.each { |config| config.update!(key: key) unless config[:key_id] == key.id }
          podcast.update!(apple_key: key) unless podcast.apple_key_id == key.id
        end

        report[:podcast_keys_assigned] += 1 if assigns_podcast_key
        action = if !changes_key_route
          "unchanged"
        elsif dry_run
          "would_assign"
        else
          "assign"
        end
        report[:key_actions] << {
          podcast_id: podcast.id,
          action: action,
          key_id: key.id,
          changes: changes
        }

        key
      end
      private_class_method :backfill_podcast_key!

      def self.backfill_config!(config, report, dry_run:)
        public_feed = config.public_feed
        legacy_show_id = legacy_apple_show_id(config, public_feed)

        return skip_config(config, report, "missing public feed") unless public_feed
        return skip_config(config, report, "missing show id") unless legacy_show_id.present?

        binding = Apple::ShowFeedBinding.find_or_initialize_by(feed: public_feed)
        binding_was_new = binding.new_record?
        needs_link = binding_was_new || config.show_feed_binding_id != binding.id
        changes = {}

        if binding_was_new
          changes[:create] = {
            feed_id: public_feed.id,
            apple_show_id: legacy_show_id
          }
        elsif binding.apple_show_id != legacy_show_id
          changes[:apple_show_id] = {from: binding.apple_show_id, to: legacy_show_id}
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
