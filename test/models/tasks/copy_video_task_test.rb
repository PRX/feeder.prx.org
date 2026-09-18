require "test_helper"

describe Tasks::CopyVideoTask do
  let(:task) { build_stubbed(:copy_video_task) }
  let(:uncut) { task.owner }
  let(:episode) { uncut.episode }

  describe "#porter_options" do
    it "inspects, copies, transcodes, and waveforms" do
      opts = task.porter_options

      assert_equal 3, opts[:Tasks].count
      assert_equal "Inspect", opts[:Tasks][0][:Type]
      assert_equal "Copy", opts[:Tasks][1][:Type]
      assert_equal "Transcode", opts[:Tasks][2][:Type]

      # just copying the video mp4
      assert_equal "test/video.mp4", opts[:Source][:ObjectKey]
      assert_equal "#{episode.path}/#{uncut.guid}.mp4", uncut.path
      assert_equal uncut.path, opts[:Tasks][1][:ObjectKey]

      # transcoding a preview mp3
      assert_equal "mp3", opts[:Tasks][2][:Format]
      assert_equal "-b:a 128k", opts[:Tasks][2][:FFmpeg][:OutputFileOptions]
      assert_equal "#{uncut.path}/preview.mp3", opts[:Tasks][2][:Destination][:ObjectKey]

      # waveforms the preview mp3
      assert_equal 1, opts[:SerializedJobs].count
      assert_equal opts[:Id], opts[:SerializedJobs][0][:Job][:Id]

      job2 = opts[:SerializedJobs][0][:Job]
      assert_equal "#{uncut.path}/preview.mp3", job2[:Source][:ObjectKey]
      assert_equal 1, job2[:Tasks].count
      assert_equal "Waveform", job2[:Tasks][0][:Type]
      assert_equal "#{uncut.path}.json", job2[:Tasks][0][:Destination][:ObjectKey]
    end

    it "transcodes to default feed bitrate" do
      episode.podcast.default_feed.audio_format = {f: "mp3", b: 160, c: 1, s: 48000}
      assert_equal "-b:a 160k", task.porter_mp3_task[:FFmpeg][:OutputFileOptions]

      # ignores non-mp3
      episode.podcast.default_feed.audio_format = {f: "flac", b: 16, c: 1, s: 48000}
      assert_equal "-b:a 192k", task.porter_mp3_task[:FFmpeg][:OutputFileOptions]

      # default is 192
      episode.podcast.default_feed.audio_format = nil
      assert_equal "-b:a 192k", task.porter_mp3_task[:FFmpeg][:OutputFileOptions]
    end
  end

  describe "#handle_callback" do
    let(:task) { Tasks::CopyVideoTask.new }
    let(:res1) { build(:porter_inspect_video_result) }
    let(:res2) { build(:porter_copy_result) }
    let(:res3) { build(:porter_slice_audio_result) }
    let(:res4) { build(:porter_waveform_result) }

    it "accumulates task results as the serialized job runs" do
      t = Time.now

      # outer job - inspect/copy/transcode
      task.handle_callback("processing", t + 1, JobReceived: {})
      task.handle_callback("processing", t + 2, TaskResult: {Result: res1})
      task.handle_callback("processing", t + 3, TaskResult: {Result: res2})
      task.handle_callback("processing", t + 4, TaskResult: {Result: res3})
      task.handle_callback("complete", t + 5, JobResult: {TaskResults: [res1, res2, res3]})

      # should stay in processing - waiting for waveform
      assert_equal "processing", task.status

      # serialized job - waveform
      task.handle_callback("processing", t + 6, JobReceived: {})
      task.handle_callback("processing", t + 7, TaskResult: {Result: res4})
      task.handle_callback("complete", t + 8, JobResult: {TaskResults: [res4]})

      # should complete with all 4 results
      assert_equal "complete", task.status
      assert_equal [res1, res2, res3, res4], task.result[:JobResult][:TaskResults]
    end

    it "handles out of order callbacks" do
      t = Time.now

      # pretend the 2nd JobReceived comes in before the 1st JobResult
      task.handle_callback("processing", t + 0, JobReceived: {})
      task.handle_callback("processing", t + 1, TaskResult: {Result: res1})
      task.handle_callback("processing", t + 2, TaskResult: {Result: res2})
      task.handle_callback("processing", t + 5, JobReceived: {})

      # these are now "ignored" - timestamps are < (t + 5)
      task.handle_callback("processing", t + 3, TaskResult: {Result: res3})
      task.handle_callback("complete", t + 4, JobResult: {TaskResults: [res1, res2, res3]})

      # but we did get their results
      assert_equal "processing", task.status
      assert_equal t + 5, task.logged_at
      assert_equal 3, task.result[:JobReceived][:TaskResults].count

      # add the remaining callbacks
      task.handle_callback("complete", t + 8, JobResult: {TaskResults: [res4]})
      task.handle_callback("processing", t + 7, TaskResult: {Result: res4})

      # should complete with all 4 results
      assert_equal "complete", task.status
      assert_equal t + 8, task.logged_at
      assert_equal [res1, res2, res3, res4], task.result[:JobResult][:TaskResults]
    end

    it "handles out of order job results" do
      t = Time.now

      # we get the 2nd job result first
      task.handle_callback("processing", t + 0, JobReceived: {})
      task.handle_callback("complete", t + 8, JobResult: {TaskResults: [res4]})
      assert_equal "processing", task.status

      # still adds the other result
      task.handle_callback("complete", t + 4, JobResult: {TaskResults: [res1, res2, res3]})
      assert_equal "complete", task.status
      assert_equal [res4, res1, res2, res3], task.result[:JobResult][:TaskResults]
    end
  end
end
