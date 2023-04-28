require "test_helper"

describe ImageFile do
  let(:url) { "http://some/where/file.png" }
  let(:image) { build_stubbed(:feed_image) }

  describe ".build" do
    it "builds from hashes" do
      i = FeedImage.build(original_url: url)
      assert_equal i.original_url, url
    end

    it "builds from strings" do
      i = FeedImage.build(url)
      assert_equal i.original_url, url
    end

    it "builds from records" do
      i = FeedImage.build(image)
      assert_equal i, image
    end

    it "returns nil when no original_url" do
      assert_nil FeedImage.build(original_url: nil)
      assert_nil FeedImage.build("")
    end
  end

  describe "#copy_media" do
    it "creates a task" do
      task = Tasks::CopyImageTask.new
      create_task = ->(&block) do
        block.call(task)
        task
      end

      Tasks::CopyImageTask.stub(:create!, create_task) do
        task.stub(:start!, true) do
          image.task = nil
          image.copy_media
          assert_equal image, task.owner
        end
      end
    end
  end

  describe "#url" do
    it "assigns the published url" do
      i = FeedImage.new

      i.stub(:published_url, url) do
        assert_nil i[:url]
        assert_equal i.url, url
      end
    end
  end

  describe "#href" do
    it "checks if processing is complete" do
      assert_equal "complete", image.status
      assert_equal image.url, image.href

      image.status = "processing"
      assert_equal image.original_url, image.href
    end
  end

  describe "#href=" do
    it "resets image attributes if changed" do
      assert_equal 144, image.width

      image.href = image.original_url
      assert_equal 144, image.width

      image.href = url
      assert_nil image.width
      assert_equal "created", image.status
    end
  end

  describe "#replace?" do
    it "checks original urls" do
      refute image.replace?(FeedImage.new(original_url: image.original_url))
      assert image.replace?(FeedImage.new(original_url: url))
    end
  end

  describe "update_image" do
    it "sets alt/caption/credit" do
      i = FeedImage.new
      image.update_image(i)

      assert_equal image.alt_text, i.alt_text
      assert_equal image.caption, i.caption
      assert_equal image.credit, i.credit
    end
  end

  describe "#retryable?" do
    it "allows retrying stale processing" do
      refute image.retryable?

      # updated 10 seconds ago
      image.updated_at = Time.now - 10
      refute image.tap { |i| i.status = "started" }.retryable?
      refute image.tap { |i| i.status = "processing" }.retryable?
      refute image.tap { |i| i.status = "complete" }.retryable?

      # updated 1 minute ago
      image.updated_at = Time.now - 60
      assert image.tap { |i| i.status = "started" }.retryable?
      assert image.tap { |i| i.status = "processing" }.retryable?
      refute image.tap { |i| i.status = "complete" }.retryable?
    end
  end

  describe "#retry!" do
    it "forces a new copy media job" do
      mock_copy = Minitest::Mock.new
      mock_copy.expect :call, nil, [true]
      i = create(:feed_image)

      i.stub(:copy_media, mock_copy) do
        i.retry!
        assert i.status_retrying?
      end

      mock_copy.verify
    end
  end
end
