# frozen_string_literal: true

module Apple
  # Transitional console-run service that stamps existing Apple episode and
  # delegated-delivery state with the show established by ShowFeedBinding.
  # Run in production as a dry run, a backfill, and then a verification. Delete
  # after the show-scoped constraints are enforced and the compatibility reads
  # are removed.
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
      return {reason: "missing episode or Apple config"} unless podcast_id

      show_resolution_by_podcast_id.fetch(podcast_id)
    end

    def each_record
      target_relations.each do |record_type, relation|
        relation.find_each(batch_size: BATCH_SIZE) { |record| yield record_type, record }
      end
    end

    def each_unscoped_record
      target_relations.each do |record_type, relation|
        relation.where(apple_show_id: nil).find_each(batch_size: BATCH_SIZE) { |record| yield record_type, record }
      end
    end

    def podcast_id_by_episode_id
      @podcast_id_by_episode_id ||= ::Episode.with_deleted
        .where(podcast_id: show_resolution_by_podcast_id.keys)
        .pluck(:id, :podcast_id)
        .to_h
    end

    def show_resolution_by_podcast_id
      @show_resolution_by_podcast_id ||= begin
        configs = Apple::Config.includes(:show_feed_binding).to_a
        podcast_id_by_feed_id = Feed.with_deleted.where(id: configs.map(&:feed_id)).pluck(:id, :podcast_id).to_h

        configs
          .group_by { |config| podcast_id_by_feed_id.fetch(config.feed_id) }
          .transform_values { |podcast_configs| show_resolution(podcast_configs) }
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
