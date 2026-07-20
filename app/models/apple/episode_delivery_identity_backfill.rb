# frozen_string_literal: true

module Apple
  # Transitional console-run service that stamps existing Apple episode and
  # delegated-delivery state with the show established by ShowFeedBinding.
  # Run in production as a dry run, a backfill, and then a verification. Delete
  # after the show-scoped constraints are enforced and the compatibility reads
  # are removed.
  # TODO: remove with cutover.
  class EpisodeDeliveryIdentityBackfill
    BATCH_SIZE = 5_000
    TARGET_TYPES = %i[episode_sync_logs podcast_containers delivery_statuses].freeze

    def self.backfill!(dry_run: false)
      new.backfill!(dry_run: dry_run)
    end

    def self.verify!
      new.verify!
    end

    def backfill!(dry_run: false)
      report = {
        dry_run: dry_run,
        row_counts: row_counts,
        unscoped_counts: unscoped_counts,
        updated: 0,
        skipped: 0,
        changed: 0,
        actions: [],
        skipped_rows: []
      }

      each_unscoped_record do |record_type, record|
        backfill_record!(record_type, record, report, dry_run: dry_run)
      end

      report
    end

    def verify!
      report = {
        row_counts: row_counts,
        remaining_null_show_rows: empty_type_report,
        mismatched_show_rows: [],
        resolution_errors: []
      }

      each_record do |record_type, record|
        if record.apple_show_id.blank?
          report[:remaining_null_show_rows][record_type] << record_details(record_type, record)
          next
        end

        resolution = resolve_apple_show_id(record)
        unless resolution[:apple_show_id].present?
          report[:resolution_errors] << record_details(record_type, record).merge(reason: resolution[:reason])
          next
        end

        if record.apple_show_id != resolution[:apple_show_id]
          report[:mismatched_show_rows] << record_details(record_type, record).merge(
            apple_show_id: record.apple_show_id,
            expected_apple_show_id: resolution[:apple_show_id]
          )
        end
      end

      report
    end

    private

    def backfill_record!(record_type, record, report, dry_run:)
      resolution = resolve_apple_show_id(record)
      unless resolution[:apple_show_id].present?
        report[:skipped] += 1
        report[:skipped_rows] << record_details(record_type, record).merge(reason: resolution[:reason])
        return
      end

      apple_show_id = resolution[:apple_show_id]
      record.update_columns(apple_show_id: apple_show_id) unless dry_run

      report[:updated] += 1
      report[:changed] += 1
      report[:actions] << record_details(record_type, record).merge(
        action: dry_run ? "would_update" : "update",
        apple_show_id: apple_show_id
      )
    end

    def resolve_apple_show_id(record)
      episode_id = episode_id_for(record)
      podcast_id = podcast_id_by_episode_id[episode_id]
      return {reason: "missing episode"} unless podcast_id

      show_resolution_by_podcast_id.fetch(podcast_id, {reason: "missing Apple show identity"})
    end

    def each_record
      target_relations.each do |record_type, relation|
        relation.find_each(batch_size: BATCH_SIZE) { |record| yield record_type, record }
      end
    end

    def each_unscoped_record
      target_relations.each do |record_type, relation|
        # TODO: remove with cutover after all legacy NULL-show rows are stamped.
        relation.where(apple_show_id: nil).find_each(batch_size: BATCH_SIZE) { |record| yield record_type, record }
      end
    end

    def podcast_id_by_episode_id
      @podcast_id_by_episode_id ||= ::Episode.with_deleted
        .where(id: target_episode_ids)
        .pluck(:id, :podcast_id)
        .to_h
    end

    def target_episode_ids
      @target_episode_ids ||= (
        ::SyncLog.apple.episodes.distinct.pluck(:feeder_id) +
        Apple::PodcastContainer.distinct.pluck(:episode_id) +
        Integrations::EpisodeDeliveryStatus.apple.distinct.pluck(:episode_id)
      ).compact.uniq
    end

    def show_resolution_by_podcast_id
      @show_resolution_by_podcast_id ||= begin
        configs = Apple::Config.includes(:show_feed_binding).to_a
        podcast_id_by_feed_id = Feed.with_deleted.where(id: configs.map(&:feed_id)).pluck(:id, :podcast_id).to_h

        resolutions = configs
          .group_by { |config| podcast_id_by_feed_id.fetch(config.feed_id) }
          .transform_values { |podcast_configs| show_resolution(podcast_configs) }

        legacy_show_ids_by_podcast_id.each do |podcast_id, apple_show_ids|
          resolutions[podcast_id] ||= legacy_show_resolution(apple_show_ids)
        end

        resolutions
      end
    end

    def legacy_show_ids_by_podcast_id
      @legacy_show_ids_by_podcast_id ||= begin
        feeds = Feed.with_deleted.where.not(podcast_id: nil).pluck(:id, :podcast_id, :apple_show_id)
        podcast_id_by_feed_id = feeds.to_h { |feed_id, podcast_id, _apple_show_id| [feed_id, podcast_id] }
        show_ids = Hash.new { |hash, podcast_id| hash[podcast_id] = [] }

        feeds.each do |_feed_id, podcast_id, apple_show_id|
          show_ids[podcast_id] << apple_show_id if apple_show_id.present?
        end

        ::SyncLog.apple.feeds.where(feeder_id: podcast_id_by_feed_id.keys).find_each do |sync_log|
          podcast_id = podcast_id_by_feed_id[sync_log.feeder_id]
          show_ids[podcast_id] << sync_log.external_id if podcast_id && sync_log.external_id.present?
        end

        show_ids.transform_values(&:uniq)
      end
    end

    def legacy_show_resolution(apple_show_ids)
      if apple_show_ids.one?
        {apple_show_id: apple_show_ids.first}
      else
        {reason: "ambiguous legacy Apple show ids: #{apple_show_ids.sort.join(", ")}"}
      end
    end

    def show_resolution(configs)
      bindings = configs.filter_map(&:show_feed_binding).uniq

      if bindings.empty?
        {reason: "missing show feed binding"}
      elsif bindings.many?
        {reason: "ambiguous show feed bindings: #{bindings.map(&:id).sort.join(", ")}"}
      else
        {apple_show_id: bindings.first.apple_show_id}
      end
    end

    def target_relations
      {
        episode_sync_logs: ::SyncLog.apple.episodes,
        podcast_containers: Apple::PodcastContainer.all,
        delivery_statuses: Integrations::EpisodeDeliveryStatus.apple
      }
    end

    def row_counts
      target_relations.transform_values(&:count)
    end

    def unscoped_counts
      # TODO: remove with cutover after all legacy NULL-show rows are stamped.
      target_relations.transform_values { |relation| relation.where(apple_show_id: nil).count }
    end

    def empty_type_report
      TARGET_TYPES.index_with { [] }
    end

    def episode_id_for(record)
      record.is_a?(::SyncLog) ? record.feeder_id : record.episode_id
    end

    def record_details(record_type, record)
      {
        record_type: record_type,
        record_id: record.id,
        episode_id: episode_id_for(record)
      }
    end
  end
end
