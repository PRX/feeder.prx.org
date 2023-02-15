require "test_helper"

describe Tasks::CopyImageTask do
  let(:task) { create(:copy_image_task) }
  let(:image) { task.owner }
  let(:path) { image.episode.podcast.path }

  it "has task options" do
    opts = task.task_options
    assert_equal opts[:job_type], "file"
    assert_equal opts[:source], image.original_url
    assert_match(/s3:\/\/test-prx-feed\/#{path}\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/images\/4e745a8c-77ee-481c-a72b-fd868dfd1c9(\d+)\/image\.png/, opts[:destination])
  end

  it "gets the image path" do
    assert_equal task.image_path(image), "/#{path}/#{image.episode.guid}/images/#{image.guid}/image.png"
  end

  it "updates status before save" do
    assert_equal task.status, "complete"
    assert_equal task.image_resource.status, "complete"
    task.update(status: "processing")
    assert_equal task.status, "processing"
    assert_equal task.image_resource.status, "processing"
  end

  it "replaces resources and publishes on complete" do
    publish = MiniTest::Mock.new

    task.podcast.stub(:publish!, publish) do
      task.update(status: "created")
      publish.verify

      publish.expect(:call, nil)
      task.update(status: "complete")
      publish.verify
    end
  end

  it "updates the image url on complete" do
    task.image_resource.update(url: "what/ever")

    task.update(status: "created")
    assert_equal task.image_resource[:url], "what/ever"
    refute_equal task.image_resource.url, "what/ever"
    assert_equal task.image_resource.url, task.image_resource.original_url

    task.update(status: "complete")
    refute_equal task.image_resource[:url], "what/ever"
    assert_equal task.image_resource[:url], task.image_resource.published_url
    refute_equal task.image_resource.url, "what/ever"
    assert_equal task.image_resource.url, task.image_resource.published_url
  end
end
