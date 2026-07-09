# frozen_string_literal: true

class SyncLog
  # Transitional migration service: scopes legacy Apple episode SyncLog rows to
  # their Apple show using legacy apple_configs, feeds.apple_show_id, and
  # public-feed SyncLog rows. This assumes ShowFeedBinding::Backfill's episode
  # consistency audit passed, proving each podcast kept the same Apple show for
  # the lifetime of its legacy episode state. Run by hand in the production
  # console (dry-run, backfill, verify). Delete once legacy NULL-show episode
  # rows are gone.
  class AppleShowBackfill
    def self.backfill!(dry_run: false)
      report = new_backfill_report(dry_run: dry_run)

      SyncLog.apple.episodes.where(apple_show_id: nil).find_each do |sync_log|
        report[:sync_logs_total] += 1
        backfill_sync_log!(sync_log, report, dry_run: dry_run)
      end

      report
    end

    def self.verify!
      null_rows = SyncLog.apple.episodes.where(apple_show_id: nil)
      multi_row_feeder_ids = SyncLog.apple.episodes.group(:feeder_id).having("COUNT(*) > 1").count

      {
        remaining_null_show_episode_rows: null_rows.map do |sync_log|
          {
            sync_log_id: sync_log.id,
            feeder_id: sync_log.feeder_id,
            external_id: sync_log.external_id
          }
        end,
        multi_row_episode_feeder_ids: multi_row_feeder_ids.map do |feeder_id, count|
          {feeder_id: feeder_id, count: count}
        end
      }
    end

    def self.new_backfill_report(dry_run:)
      {
        dry_run: dry_run,
        sync_logs_total: 0,
        updated: 0,
        skipped: 0,
        changed: 0,
        actions: [],
        skipped_sync_logs: []
      }
    end
    private_class_method :new_backfill_report

    def self.backfill_sync_log!(sync_log, report, dry_run:)
      resolution = resolve_apple_show_id(sync_log)
      return skip_sync_log(sync_log, report, resolution[:reason]) unless resolution[:apple_show_id].present?

      apple_show_id = resolution[:apple_show_id]
      unless dry_run
        sync_log.update!(apple_show_id: apple_show_id)
      end

      report[:updated] += 1
      report[:changed] += 1
      report[:actions] << {
        sync_log_id: sync_log.id,
        action: dry_run ? "would_update" : "update",
        feeder_id: sync_log.feeder_id,
        external_id: sync_log.external_id,
        apple_show_id: apple_show_id
      }
    end
    private_class_method :backfill_sync_log!

    def self.resolve_apple_show_id(sync_log)
      episode = Episode.with_deleted.find_by(id: sync_log.feeder_id)
      return {reason: "missing episode"} unless episode

      podcast = episode.podcast
      return {reason: "missing podcast"} unless podcast

      config = podcast.apple_config
      return {reason: "missing config"} unless config

      apple_show_id = legacy_apple_show_id(config)
      return {reason: "missing show id"} unless apple_show_id.present?

      {apple_show_id: apple_show_id}
    end
    private_class_method :resolve_apple_show_id

    def self.legacy_apple_show_id(config)
      sync_log = SyncLog.apple.feeds.find_by(feeder_id: config.public_feed&.id)
      sync_log&.external_id.presence || config.private_feed&.apple_show_id.presence
    end
    private_class_method :legacy_apple_show_id

    def self.skip_sync_log(sync_log, report, reason)
      report[:skipped] += 1
      report[:skipped_sync_logs] << {
        sync_log_id: sync_log.id,
        feeder_id: sync_log.feeder_id,
        external_id: sync_log.external_id,
        reason: reason
      }
    end
    private_class_method :skip_sync_log
  end
end
