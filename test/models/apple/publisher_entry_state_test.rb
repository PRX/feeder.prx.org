# frozen_string_literal: true

require "test_helper"

# Entry State Matrix for Apple::Publisher#upload_and_process!
#
# This test suite covers the different states an episode can be in when it
# (re-)enters the Apple publishing pipeline via upload_and_process!.
#
# Entry States:
#
# | State | delivered | uploaded | media_ver_match | How it got here                          |
# |-------|-----------|----------|-----------------|------------------------------------------|
# | A     | nil       | nil      | no              | Brand new episode, first publish         |
# | B     | false     | true     | yes             | General timeout: uploaded ok, asset      |
# |       |           |          |                 | processing timed out, re-entered         |
# | C     | false     | false    | yes*            | Stuck episode: check_for_stuck reset     |
# |       |           |          |                 | both delivered+uploaded via              |
# |       |           |          |                 | mark_as_not_delivered!                   |
# | D     | true      | true     | no              | Media changed on a delivered episode     |
# | E     | false     | true     | no              | General timeout + media re-processed     |
#
# * source_media_version_id preserved by mark_as_not_delivered!
#
# Gate logic:
#   apple_needs_upload?   = !uploaded || !has_media_version?
#   apple_needs_delivery? = delivered == false
#   (upload_media! also sets delivered=false via prepare_for_delivery!)
#
# Expected outcomes:
#
# | State | sync? | upload? | delivery? | Notes                                    |
# |-------|-------|---------|-----------|------------------------------------------|
# | A     | YES   | YES     | YES       | Full pipeline                            |
# | B     | YES   | NO      | YES       | Skip upload, finish delivery             |
# | C     | YES   | YES     | YES       | Full retry (stuck = broken)              |
# | D     | YES   | YES     | YES       | New media needs full pipeline            |
# | E     | YES   | YES     | YES       | Re-upload needed (media version stale)   |
#
# Ejection points (where episodes exit early or error out):
#   - episodes_to_sync filter (synced_with_apple? = true -> excluded entirely)
#   - apple_needs_upload? gate -> skip upload_media!
#   - apple_needs_delivery? gate -> skip process_delivery!
#   - wait_for_versioned_source_metadata timeout -> raise
#   - wait_for_upload_processing timeout -> AssetStateTimeoutError
#   - wait_for_asset_state timeout -> AssetStateTimeoutError
#   - check_for_stuck_episodes -> mark_as_not_delivered! + AssetStateTimeoutError
#   - raise_delivery_processing_errors -> VALIDATION_FAILED -> mark_as_not_delivered! + raise

# Lightweight test doubles for structural routing tests (no AR overhead).
module PublisherEntryStateDoubles
  class EpisodeDouble
    attr_reader :name

    def initialize(name:, needs_upload: false, needs_delivery: false)
      @name = name
      @needs_upload = needs_upload
      @needs_delivery = needs_delivery
    end

    def apple_needs_upload?
      @needs_upload
    end

    def apple_needs_delivery?
      @needs_delivery
    end
  end
end

describe Apple::Publisher do
  let(:podcast) { create(:podcast) }
  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:apple_feed, podcast: podcast) }
  let(:apple_config) { private_feed.apple_config }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }
  let(:apple_publisher) do
    Apple::Publisher.new(api: apple_api, public_feed: public_feed, private_feed: private_feed)
  end

  # Helper: track which phases were called and in what order (AR-based tests)
  def track_phases(publisher, episodes)
    phases = []

    sync_mock = ->(*) { phases << :sync }
    upload_mock = ->(eps) { phases << [:upload, eps.map(&:feeder_id)] }
    delivery_mock = ->(eps) { phases << [:delivery, eps.map(&:feeder_id)] }

    publisher.stub(:sync_episodes!, sync_mock) do
      publisher.stub(:upload_media!, upload_mock) do
        publisher.stub(:process_delivery!, delivery_mock) do
          publisher.upload_and_process!(episodes)
        end
      end
    end

    phases
  end

  # Helpers for test-double-based structural tests
  def build_routing_episodes(episode_rows)
    episode_rows.map do |row|
      PublisherEntryStateDoubles::EpisodeDouble.new(
        name: row.fetch(:name),
        needs_upload: row.fetch(:needs_upload),
        needs_delivery: row.fetch(:needs_delivery)
      )
    end
  end

  def record_labels(records)
    Array(records).map { |r| r.name }
  end

  # =========================================================================
  # Part 1: Entry state gate tests (AR-based, real status records)
  # =========================================================================
  describe "Entry State Matrix: #upload_and_process!" do
    # -------------------------------------------------------------------------
    # State A: Brand new episode, first publish
    #   delivered=nil, uploaded=nil, media_version_match=no
    #   Expected: sync YES, upload YES, delivery YES
    # -------------------------------------------------------------------------
    describe "State A: new episode (first publish)" do
      let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

      before do
        episode.feeder_episode.episode_delivery_statuses.destroy_all
        episode.feeder_episode.episode_delivery_statuses.reset
      end

      it "needs upload (no status)" do
        assert episode.feeder_episode.apple_needs_upload?
      end

      it "needs delivery (no status)" do
        assert episode.needs_delivery?
      end

      it "enters both upload and delivery phases" do
        phases = track_phases(apple_publisher, [episode])

        assert phases.any? { |p| p.is_a?(Array) && p[0] == :upload },
          "should enter upload phase"
        assert phases.any? { |p| p.is_a?(Array) && p[0] == :delivery },
          "should enter delivery phase"
      end
    end

    # -------------------------------------------------------------------------
    # State B: General timeout re-entry
    #   delivered=false, uploaded=true, media_version_match=yes
    #   Expected: sync YES, upload NO, delivery YES
    # -------------------------------------------------------------------------
    describe "State B: general timeout re-entry (uploaded, not delivered)" do
      let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

      before do
        episode.feeder_episode.apple_update_delivery_status(
          uploaded: true,
          delivered: false,
          source_media_version_id: episode.feeder_episode.media_version_id,
          asset_processing_attempts: 3
        )
      end

      it "does not need upload (uploaded + media version current)" do
        refute episode.feeder_episode.apple_needs_upload?
      end

      it "needs delivery (delivered=false)" do
        assert episode.feeder_episode.apple_needs_delivery?
      end

      it "skips upload but enters delivery" do
        phases = track_phases(apple_publisher, [episode])

        refute phases.any? { |p| p.is_a?(Array) && p[0] == :upload },
          "should NOT enter upload phase"
        assert phases.any? { |p| p.is_a?(Array) && p[0] == :delivery },
          "should enter delivery phase"
      end

      it "is not considered synced (still needs work)" do
        refute episode.synced_with_apple?,
          "episode should not be filtered out by episodes_to_sync"
      end
    end

    # -------------------------------------------------------------------------
    # State C: Stuck episode re-entry
    #   delivered=false, uploaded=false, media_version_match=yes
    #   Expected: sync YES, upload YES, delivery YES (full retry)
    # -------------------------------------------------------------------------
    describe "State C: stuck episode re-entry (mark_as_not_delivered! reset)" do
      let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

      before do
        episode.feeder_episode.apple_update_delivery_status(
          uploaded: true,
          delivered: false,
          source_media_version_id: episode.feeder_episode.media_version_id
        )
        episode.feeder_episode.apple_mark_as_not_delivered!
      end

      it "needs upload (uploaded was reset to false)" do
        assert episode.feeder_episode.apple_needs_upload?
      end

      it "needs delivery (delivered=false)" do
        assert episode.feeder_episode.apple_needs_delivery?
      end

      it "preserves source_media_version_id" do
        status = episode.feeder_episode.apple_episode_delivery_status
        assert status.source_media_version_id.present?,
          "source_media_version_id should be preserved by mark_as_not_delivered!"
      end

      it "enters both upload and delivery phases (full retry)" do
        phases = track_phases(apple_publisher, [episode])

        assert phases.any? { |p| p.is_a?(Array) && p[0] == :upload },
          "should enter upload phase (full retry for stuck)"
        assert phases.any? { |p| p.is_a?(Array) && p[0] == :delivery },
          "should enter delivery phase"
      end
    end

    # -------------------------------------------------------------------------
    # State D: Media changed on delivered episode
    #   delivered=true, uploaded=true, media_version_match=no
    #   Expected: sync YES, upload YES, delivery YES
    # -------------------------------------------------------------------------
    describe "State D: media changed on delivered episode" do
      let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

      before do
        episode.feeder_episode.apple_update_delivery_status(
          uploaded: true,
          delivered: true,
          source_media_version_id: episode.feeder_episode.media_version_id
        )
        create(:content, episode: episode.feeder_episode, position: 3, status: "complete")
        episode.feeder_episode.reload.cut_media_version!
      end

      it "needs upload (media version mismatch)" do
        assert episode.feeder_episode.apple_needs_upload?
      end

      it "enters upload phase" do
        phases = track_phases(apple_publisher, [episode])

        assert phases.any? { |p| p.is_a?(Array) && p[0] == :upload },
          "should enter upload phase for changed media"
      end

      it "is not considered synced (media version changed)" do
        refute episode.synced_with_apple?,
          "episode should not be filtered out by episodes_to_sync"
      end
    end

    # -------------------------------------------------------------------------
    # State E: General timeout + media changed
    #   delivered=false, uploaded=true, media_version_match=no
    #   Episode was uploaded, timed out during asset processing, then the
    #   user re-processed the media (new media version). uploaded=true is
    #   stale — needs_upload? catches this via has_media_version? check.
    #   Expected: sync YES, upload YES, delivery YES
    # -------------------------------------------------------------------------
    describe "State E: general timeout re-entry with media change" do
      let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

      before do
        # Simulate: uploaded successfully, then timed out
        episode.feeder_episode.apple_update_delivery_status(
          uploaded: true,
          delivered: false,
          source_media_version_id: episode.feeder_episode.media_version_id,
          asset_processing_attempts: 3
        )
        # Then media was re-processed — new version that doesn't match
        create(:content, episode: episode.feeder_episode, position: 3, status: "complete")
        episode.feeder_episode.reload.cut_media_version!
      end

      it "needs upload (media version mismatch overrides uploaded=true)" do
        assert episode.feeder_episode.apple_needs_upload?
      end

      it "needs delivery (delivered=false)" do
        assert episode.feeder_episode.apple_needs_delivery?
      end

      it "enters both upload and delivery phases" do
        phases = track_phases(apple_publisher, [episode])

        assert phases.any? { |p| p.is_a?(Array) && p[0] == :upload },
          "should enter upload phase (media changed despite uploaded=true)"
        assert phases.any? { |p| p.is_a?(Array) && p[0] == :delivery },
          "should enter delivery phase"
      end
    end

    # -------------------------------------------------------------------------
    # Ejection: fully synced episode is excluded from episodes_to_sync
    # -------------------------------------------------------------------------
    describe "Ejection: fully synced episode excluded from pipeline" do
      let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

      before do
        episode.feeder_episode.apple_update_delivery_status(
          uploaded: true,
          delivered: true,
          source_media_version_id: episode.feeder_episode.media_version_id
        )
      end

      it "is considered synced" do
        assert episode.synced_with_apple?
      end

      it "is filtered out by filter_episodes_to_sync" do
        result = apple_publisher.send(:filter_episodes_to_sync, [episode])
        assert_empty result, "fully synced episode should be excluded"
      end
    end

    # -------------------------------------------------------------------------
    # State B vs C contrast: the key distinction this PR introduces
    # -------------------------------------------------------------------------
    describe "State B vs C: timeout re-entry preserves upload, stuck does not" do
      let(:episode) { build(:uploaded_apple_episode, show: apple_publisher.show) }

      it "general timeout: uploaded stays true, upload skipped" do
        episode.feeder_episode.apple_update_delivery_status(
          uploaded: true,
          delivered: false,
          source_media_version_id: episode.feeder_episode.media_version_id,
          asset_processing_attempts: 3
        )

        phases = track_phases(apple_publisher, [episode])

        refute phases.any? { |p| p.is_a?(Array) && p[0] == :upload },
          "general timeout re-entry should NOT re-upload"
        assert phases.any? { |p| p.is_a?(Array) && p[0] == :delivery },
          "general timeout re-entry should proceed to delivery"
      end

      it "stuck timeout: uploaded reset to false, full re-upload" do
        episode.feeder_episode.apple_update_delivery_status(
          uploaded: true,
          delivered: false,
          source_media_version_id: episode.feeder_episode.media_version_id
        )
        episode.feeder_episode.apple_mark_as_not_delivered!

        phases = track_phases(apple_publisher, [episode])

        assert phases.any? { |p| p.is_a?(Array) && p[0] == :upload },
          "stuck re-entry SHOULD re-upload"
        assert phases.any? { |p| p.is_a?(Array) && p[0] == :delivery },
          "stuck re-entry should proceed to delivery"
      end
    end
  end

  # =========================================================================
  # Part 2: Structural routing tests (test doubles, no AR)
  # Verifies subset routing and ejection points.
  # =========================================================================
  describe "Routing: #upload_and_process!" do
    it "syncs every episode and skips settled episodes" do
      episodes = build_routing_episodes([
        {name: :settled, needs_upload: false, needs_delivery: false}
      ])
      call_log = []

      sync_stub = ->(eps) { call_log << [:sync_episodes!, record_labels(eps)] }
      upload_stub = ->(eps) { call_log << [:upload_media!, record_labels(eps)] }
      delivery_stub = ->(eps) { call_log << [:process_delivery!, record_labels(eps)] }
      validation_stub = ->(eps) { call_log << [:raise_delivery_processing_errors, record_labels(eps)] }

      apple_publisher.stub(:sync_episodes!, sync_stub) do
        apple_publisher.stub(:upload_media!, upload_stub) do
          apple_publisher.stub(:process_delivery!, delivery_stub) do
            apple_publisher.stub(:raise_delivery_processing_errors, validation_stub) do
              apple_publisher.upload_and_process!(episodes)
            end
          end
        end
      end

      assert_equal [
        [:sync_episodes!, [:settled]],
        [:raise_delivery_processing_errors, [:settled]]
      ], call_log
    end

    it "routes delivery-only episodes without re-uploading" do
      episodes = build_routing_episodes([
        {name: :delivery_only, needs_upload: false, needs_delivery: true}
      ])
      call_log = []

      sync_stub = ->(eps) { call_log << [:sync_episodes!, record_labels(eps)] }
      upload_stub = ->(eps) { call_log << [:upload_media!, record_labels(eps)] }
      delivery_stub = ->(eps) { call_log << [:process_delivery!, record_labels(eps)] }
      validation_stub = ->(eps) { call_log << [:raise_delivery_processing_errors, record_labels(eps)] }

      apple_publisher.stub(:sync_episodes!, sync_stub) do
        apple_publisher.stub(:upload_media!, upload_stub) do
          apple_publisher.stub(:process_delivery!, delivery_stub) do
            apple_publisher.stub(:raise_delivery_processing_errors, validation_stub) do
              apple_publisher.upload_and_process!(episodes)
            end
          end
        end
      end

      assert_equal [
        [:sync_episodes!, [:delivery_only]],
        [:process_delivery!, [:delivery_only]],
        [:raise_delivery_processing_errors, [:delivery_only]]
      ], call_log
    end

    it "routes upload-only episodes without forcing delivery" do
      episodes = build_routing_episodes([
        {name: :upload_only, needs_upload: true, needs_delivery: false}
      ])
      call_log = []

      sync_stub = ->(eps) { call_log << [:sync_episodes!, record_labels(eps)] }
      upload_stub = ->(eps) { call_log << [:upload_media!, record_labels(eps)] }
      delivery_stub = ->(eps) { call_log << [:process_delivery!, record_labels(eps)] }
      validation_stub = ->(eps) { call_log << [:raise_delivery_processing_errors, record_labels(eps)] }

      apple_publisher.stub(:sync_episodes!, sync_stub) do
        apple_publisher.stub(:upload_media!, upload_stub) do
          apple_publisher.stub(:process_delivery!, delivery_stub) do
            apple_publisher.stub(:raise_delivery_processing_errors, validation_stub) do
              apple_publisher.upload_and_process!(episodes)
            end
          end
        end
      end

      assert_equal [
        [:sync_episodes!, [:upload_only]],
        [:upload_media!, [:upload_only]],
        [:raise_delivery_processing_errors, [:upload_only]]
      ], call_log
    end

    it "routes mixed batches to correct subsets in order" do
      episodes = build_routing_episodes([
        {name: :upload_and_delivery, needs_upload: true, needs_delivery: true},
        {name: :delivery_only, needs_upload: false, needs_delivery: true},
        {name: :settled, needs_upload: false, needs_delivery: false}
      ])
      call_log = []

      sync_stub = ->(eps) { call_log << [:sync_episodes!, record_labels(eps)] }
      upload_stub = ->(eps) { call_log << [:upload_media!, record_labels(eps)] }
      delivery_stub = ->(eps) { call_log << [:process_delivery!, record_labels(eps)] }
      validation_stub = ->(eps) { call_log << [:raise_delivery_processing_errors, record_labels(eps)] }

      apple_publisher.stub(:sync_episodes!, sync_stub) do
        apple_publisher.stub(:upload_media!, upload_stub) do
          apple_publisher.stub(:process_delivery!, delivery_stub) do
            apple_publisher.stub(:raise_delivery_processing_errors, validation_stub) do
              apple_publisher.upload_and_process!(episodes)
            end
          end
        end
      end

      assert_equal [
        [:sync_episodes!, [:upload_and_delivery, :delivery_only, :settled]],
        [:upload_media!, [:upload_and_delivery]],
        [:process_delivery!, [:upload_and_delivery, :delivery_only]],
        [:raise_delivery_processing_errors, [:upload_and_delivery, :delivery_only, :settled]]
      ], call_log
    end

    it "ejects when raise_delivery_processing_errors raises" do
      episodes = build_routing_episodes([
        {name: :upload_and_delivery, needs_upload: true, needs_delivery: true}
      ])
      call_log = []

      sync_stub = ->(eps) { call_log << [:sync_episodes!, record_labels(eps)] }
      upload_stub = ->(eps) { call_log << [:upload_media!, record_labels(eps)] }
      delivery_stub = ->(eps) { call_log << [:process_delivery!, record_labels(eps)] }
      validation_stub = ->(eps) {
        call_log << [:raise_delivery_processing_errors, record_labels(eps)]
        raise Apple::PodcastDeliveryFile::DeliveryFileError, "matrix eject"
      }

      apple_publisher.stub(:sync_episodes!, sync_stub) do
        apple_publisher.stub(:upload_media!, upload_stub) do
          apple_publisher.stub(:process_delivery!, delivery_stub) do
            apple_publisher.stub(:raise_delivery_processing_errors, validation_stub) do
              assert_raises(Apple::PodcastDeliveryFile::DeliveryFileError) do
                apple_publisher.upload_and_process!(episodes)
              end
            end
          end
        end
      end

      assert_equal [
        [:sync_episodes!, [:upload_and_delivery]],
        [:upload_media!, [:upload_and_delivery]],
        [:process_delivery!, [:upload_and_delivery]],
        [:raise_delivery_processing_errors, [:upload_and_delivery]]
      ], call_log
    end
  end
end
