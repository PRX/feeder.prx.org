# Merge Conflict Report

This report records the merge conflicts present while merging `origin/main`
into `reapply-apple-drafts-upload-media`. Line numbers refer to the conflicted
working tree before resolution.

## app/models/apple/episode.rb

### Conflict 1: line 157

```ruby
151     def self.alter_publish_state(api, show, episodes, state)
152       return [] if episodes.empty?
153
154       episode_bridge_results = api.bridge_remote_and_retry!("publishEpisodes",
155         episodes.map { |e| e.publishing_state_bridge_params(state) })
156
157 <<<<<<< HEAD
158       join_on_apple_episode_id(episodes, episode_bridge_results).each do |(ep, row)|
159         Rails.logger.info("Applying #{state} action to episode",
160           apple_episode_log_context(ep).merge(action: state, prior_publishing_state: ep.publishing_state))
161 =======
162       Apple::ApiJoin.join_on_apple_episode_id(episodes, episode_bridge_results).each do |(ep, row)|
163         Rails.logger.info("Moving episode to #{state} state", {episode_id: ep.feeder_id, state: ep.publishing_state})
164 >>>>>>> origin/main
165       end
166
167       # We don't get back the full episode model in the response.
168       # So poll for current state
169       poll_episode_state(api, show, episodes)
```

Description:
`HEAD` keeps richer logging for archive, unarchive, and publish state changes,
including the action, prior state, and episode GUID. `origin/main` updates the
join helper call to the newer `Apple::ApiJoin` module. The unqualified
`join_on_apple_episode_id` call from `HEAD` depends on the older include/API
shape and would fail in the merged codebase.

Fix:
Use `Apple::ApiJoin.join_on_apple_episode_id` from `origin/main` and keep the
richer log payload from `HEAD`. The joined row is not used, so name it `_row`.

## app/models/apple/publisher.rb

### Conflict 1: line 119

```ruby
117     def upload_and_process!(eps)
118       Rails.logger.tagged("Apple::Publisher#upload_and_process!") do
119 <<<<<<< HEAD
120         eps, skipped = eps.partition { |ep| ep.feeder_episode.enclosure_ready?(true) }
121         skipped.each do |ep|
122           Rails.logger.warn("Episode needs ready enclosure. Skipping", {episode_id: ep.id})
123         end
124
125         # Sync episode metadata (create/update on Apple) for eligible episodes
126         eps.each_slice(PUBLISH_CHUNK_LEN) { |batch| sync_episodes!(batch) }
127
128         eps
129           .select(&:apple_needs_upload?)
130           .each_slice(PUBLISH_CHUNK_LEN) do |batch|
131 =======
132         # Only create if needed.
133         sync_episodes!(eps)
134
135         eps.filter(&:apple_needs_upload?).each_slice(PUBLISH_CHUNK_LEN) do |batch|
136 >>>>>>> origin/main
137           upload_media!(batch)
138         end
139
140         eps
141           .filter(&:apple_needs_delivery?)
142           .filter { |ep| ep.feeder_episode.published? }
143           .each_slice(PUBLISH_CHUNK_LEN) do |batch|
144           process_delivery!(batch)
```

Description:
This is a real workflow conflict. `HEAD` adds prepublish/draft behavior: skip
episodes without a ready enclosure, sync metadata only for eligible episodes,
upload draft media, and defer delivery until the episode is actually published.
`origin/main` moves `sync_episodes!` out of `upload_media!` so episodes that do
not need upload can still receive metadata updates before delivery.

Fix:
Combine the behavior. First filter out episodes whose enclosure is not ready and
warn about them. Then sync eligible episodes in chunks. Then upload only the
eligible episodes that need upload. Keep the existing delivery filter requiring
`feeder_episode.published?`.

### Conflict 2: line 158

```ruby
151     def upload_media!(eps)
152       Rails.logger.tagged("Apple::Publisher##{__method__}") do
153         Rails.logger.info("Starting media upload", {episode_count: eps.length})
154
155         # Soft delete any existing delivery and delivery files.
156         prepare_for_delivery!(eps)
157
158 <<<<<<< HEAD
159         # Create containers/files for episodes needing media upload.
160 =======
161 >>>>>>> origin/main
162         sync_podcast_containers!(eps)
163
164         media_infos = wait_for_versioned_source_metadata(eps)
165         episodes_with_source_metadata = media_infos.map(&:episode)
166         unless Set.new(episodes_with_source_metadata) == Set.new(eps)
167           raise "Source metadata response did not match requested episodes"
```

Description:
This conflict is only a comment, but it sits in the upload media path that
`origin/main` changed to use `Apple::MediaInfo`. The comment from `HEAD`
continues to describe why containers are synced here.

Fix:
Keep the comment and the `origin/main` `MediaInfo` flow below it.

### Conflict 3: line 553

```ruby
551     def mark_as_uploaded!(media_infos)
552       Rails.logger.tagged("##{__method__}") do
553 <<<<<<< HEAD
554         eps.each do |ep|
555           Rails.logger.info("Marking episode media as uploaded", {episode_id: ep.feeder_episode.id})
556           ep.feeder_episode.apple_mark_as_uploaded!
557 =======
558         media_infos.each do |mi|
559           attrs = mi.source_attributes.merge(uploaded: true)
560           Rails.logger.info("Marking episode as uploaded", {episode_id: mi.episode.feeder_episode.id}.merge(attrs))
561           mi.episode.feeder_episode.apple_update_delivery_status(attrs)
562 >>>>>>> origin/main
563         end
564       end
565     end
```

Description:
This is a method contract conflict. The signature already accepts
`media_infos`, but the `HEAD` body still iterates `eps`, which would be an
undefined local variable. More importantly, `HEAD` only marks the upload flag.
`origin/main` records the source metadata and media version that the upload
eligibility logic now depends on.

Fix:
Use the `origin/main` `media_infos` loop, persist `source_attributes` plus
`uploaded: true`, and keep clear upload-focused logging.

## app/models/integrations/base/episode.rb

### Conflict 1: line 39

```ruby
38       def has_media_version?
39 <<<<<<< HEAD
40         return false unless delivery_status.present?
41
42         !delivery_status.needs_media_version?
43 =======
44         delivery_status.present? && delivery_status.has_media_version?
45 >>>>>>> origin/main
46       end
47
48       def needs_media_version?
49         !has_media_version?
```

Description:
Both sides express the same high-level idea: an integration episode has the
current media version only if it has a delivery status and that status matches
the current episode media version. `origin/main` adds a clearer lower-level
`has_media_version?` method to `EpisodeDeliveryStatus`.

Fix:
Delegate to `delivery_status.has_media_version?` when a delivery status exists.

## app/models/integrations/episode_delivery_status.rb

### Conflict 1: line 66

```ruby
65     def needs_upload?
66 <<<<<<< HEAD
67       !uploaded || source_media_version_id != episode.media_version_id
68     end
69
70     def needs_media_version?
71       source_media_version_id.blank? || source_media_version_id != episode.media_version_id
72 =======
73       !uploaded || needs_media_version?
74     end
75
76     def has_media_version?
77       MediaVersion.matches_current_id?(source_media_version_id, episode.media_version_id)
78     end
79
80     def needs_media_version?
81       !has_media_version?
82 >>>>>>> origin/main
83     end
```

Description:
Both sides add media-version-aware upload checks. `HEAD` compares raw IDs
directly. `origin/main` centralizes matching through
`MediaVersion.matches_current_id?`, which also handles blank candidates
consistently and exposes a reusable `has_media_version?` API.

Fix:
Use the `origin/main` structure: `needs_upload?` is `!uploaded ||
needs_media_version?`, `has_media_version?` delegates to
`MediaVersion.matches_current_id?`, and `needs_media_version?` negates it.

## test/models/apple/publisher_test.rb

### Conflict 1: line 1231

```ruby
1230   describe "#mark_as_uploaded!" do
1231 <<<<<<< HEAD
1232     let(:episode1) { build(:apple_episode_ready_for_upload, show: apple_publisher.show) }
1233     let(:episode2) { build(:apple_episode_ready_for_upload, show: apple_publisher.show) }
1234     let(:episodes) { [episode1, episode2] }
1235 =======
1236     let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show) }
1237     let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show) }
1238 >>>>>>> origin/main
1239
1240     it "writes source attributes and uploaded flag" do
1241       media_infos = [episode1, episode2].map do |ep|
```

Description:
`HEAD` uses episodes that are ready for upload and therefore start with
`uploaded` false. `origin/main` uses `uploaded_apple_episode`, but in the merged
factory that now sets `uploaded: true`, which contradicts the later assertion
that the status is not uploaded before calling `mark_as_uploaded!`.

Fix:
Use `apple_episode_ready_for_upload` and remove the unused `episodes` helper.
This keeps the test focused on `mark_as_uploaded!` changing the flag and writing
source metadata.

### Conflict 2: line 1365

```ruby
1365 <<<<<<< HEAD
1366     it "still uploads media for draft episodes" do
1367       episode = build(:apple_episode_ready_for_upload, show: apple_publisher.show)
1368       episode.feeder_episode.update!(published_at: nil)
1369       assert episode.apple_needs_upload?
...
1429       # Second run: episode is now published and already uploaded
1430       episode.feeder_episode.reload
1431       episode.feeder_episode.update!(published_at: 1.hour.ago)
1432 =======
1433     it "skips upload when media version is unchanged" do
1434       episode = build(:uploaded_apple_episode, show: apple_publisher.show)
1435 >>>>>>> origin/main
1436       episode.feeder_episode.apple_update_delivery_status(
1437         uploaded: true,
1438         source_media_version_id: episode.feeder_episode.media_version_id
1439       )
```

Description:
This is a logical test-region conflict. `HEAD` adds draft upload and delayed
delivery coverage, including a two-run flow where a draft is uploaded first and
delivered only after publication. `origin/main` adds coverage for skipping
upload when the source media version has not changed.

Fix:
Keep the draft tests from `HEAD` and add the unchanged-media test as a separate
test immediately after the two-run draft test.

### Conflict 3: line 1441

```ruby
1441 <<<<<<< HEAD
1442       upload_called = false
1443       delivery_called = false
1444
1445       apple_publisher.stub(:upload_media!, ->(*) { upload_called = true }) do
1446         apple_publisher.stub(:process_delivery!, ->(*) { delivery_called = true }) do
1447           apple_publisher.upload_and_process!([episode])
1448         end
1449       end
1450
1451       refute upload_called, "upload_media! should not be called when already uploaded"
1452       assert delivery_called, "process_delivery! should be called after draft is published"
1453 =======
1454       refute episode.feeder_episode.apple_needs_upload?,
1455         "should not need upload when source_media_version_id matches"
...
1467       refute upload_called, "upload_media! should not be called when media is unchanged"
1468 >>>>>>> origin/main
```

Description:
This conflict is the assertion/body half of the previous logical region.
`HEAD` verifies the second run of the draft flow: once published and already
uploaded, it should skip upload and proceed to delivery. `origin/main` verifies
the unchanged-media skip-upload case.

Fix:
Use the `HEAD` assertions to finish the two-run draft test, then create a
separate unchanged-media test using the `origin/main` assertions.

### Conflict 4: line 1474

```ruby
1471     it "re-uploads when media version changes after a previous upload" do
1472       # Episode was previously uploaded and delivered with an old media version
1473       episode = build(:uploaded_apple_episode, show: apple_publisher.show)
1474 <<<<<<< HEAD
1475 =======
1476       # Current factory sets delivered but not uploaded - mark as uploaded too
1477       episode.feeder_episode.apple_update_delivery_status(
1478         uploaded: true,
1479         source_media_version_id: episode.feeder_episode.media_version_id
1480       )
1481 >>>>>>> origin/main
1482       old_version_id = episode.feeder_episode.media_version_id
```

Description:
`origin/main` added a setup correction for a factory that, in that branch, did
not set `uploaded: true`. The current merged factory already marks
`uploaded_apple_episode` as uploaded with a matching source media version.

Fix:
Drop the extra setup block as redundant, or keep it harmlessly if desired. The
resolution drops it because the factory already establishes the intended state.

### Conflict 5: line 1497

```ruby
1495       upload_called = false
1496
1497 <<<<<<< HEAD
1498       apple_publisher.stub(:upload_media!, ->(*) { upload_called = true }) do
1499         apple_publisher.stub(:process_delivery!, ->(*) {}) do
1500           apple_publisher.upload_and_process!([episode])
1501 =======
1502       apple_publisher.stub(:sync_episodes!, nil) do
1503         apple_publisher.stub(:upload_media!, ->(*) { upload_called = true }) do
1504           apple_publisher.stub(:process_delivery!, ->(*) {}) do
1505             apple_publisher.upload_and_process!([episode])
1506           end
1507 >>>>>>> origin/main
1508         end
1509       end
```

Description:
Both sides are testing the same reupload behavior. `origin/main` explicitly
stubs `sync_episodes!`; the surrounding test context already defines a no-op
`sync_episodes!`, but the explicit stub is harmless and makes the test's network
isolation obvious.

Fix:
Keep the explicit `sync_episodes!` stub and the upload assertion.

### Conflict 6: line 1514

```ruby
1514 <<<<<<< HEAD
1515     it "skips process_delivery! for scheduled episodes" do
1516       episode.feeder_episode.update!(published_at: 10.days.from_now)
...
1526       refute delivery_called, "process_delivery! should not be called for scheduled episodes"
1527     end
1528
1529 =======
1530 >>>>>>> origin/main
1531     it "processes all uploads before any deliveries (phase separation)" do
```

Description:
`HEAD` adds coverage that scheduled episodes, like drafts, can be uploaded but
must not be delivered yet. `origin/main` has no equivalent test.

Fix:
Keep the scheduled-episode delivery gating test.

## test/models/concerns/apple_integration_test.rb

### Conflict 1: line 57

```ruby
53   describe "#apple_mark_as_uploaded!" do
54     it "sets the uploaded status" do
55       episode.apple_mark_as_uploaded!
56       assert episode.apple_episode_delivery_status.uploaded
57 <<<<<<< HEAD
58
59       # Upload completion now also depends on media-version alignment.
60       episode.apple_update_delivery_status(source_media_version_id: -1)
61       assert episode.apple_needs_upload?
62
63       episode.apple_update_delivery_status(source_media_version_id: episode.media_version_id)
64 =======
65     end
66
67     it "does not need upload when media version also matches" do
68       episode.apple_episode_delivery_status.update!(source_media_version_id: episode.media_version_id)
69       episode.apple_mark_as_uploaded!
70 >>>>>>> origin/main
71       refute episode.apple_needs_upload?
72     end
```

Description:
Both sides update tests around the new requirement that `uploaded: true` is not
enough by itself. `HEAD` tests the mismatch and then match transition inside one
test. `origin/main` splits the matching case into a separate test.

Fix:
Keep both behaviors clearly: one test verifies `apple_mark_as_uploaded!` sets
the flag and still needs upload when the media version is stale, and another
test verifies upload is not needed when the media version matches.
