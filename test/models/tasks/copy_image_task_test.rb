require 'test_helper'

describe Tasks::CopyImageTask do
  let(:task) { create(:copy_image_task) }
  let(:image) { task.owner }

  it 'has task options' do
    opts = task.task_options
    assert_equal opts[:job_type], 'file'
    assert_equal opts[:source], image.original_url
    assert_match(/s3:\/\/test-prx-feed\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/images\/4e745a8c-77ee-481c-a72b-fd868dfd1c9(\d+)\/image\.png/, opts[:destination])
  end

  it 'gets the image path' do
    assert_equal task.image_path(image), "/jjgo/#{image.episode.guid}/images/#{image.guid}/image.png"
  end

  it 'updates status before save' do
    assert_equal task.status, 'complete'
    assert_equal task.image_resource.status, 'complete'
    task.update_attributes(status: 'processing')
    assert_equal task.status, 'processing'
    assert_equal task.image_resource.status, 'processing'
  end

  it 'replaces resources and publishes on complete' do
    replace = MiniTest::Mock.new
    publish = MiniTest::Mock.new

    task.image_resource.stub(:replace_resources!, replace) do
      task.podcast.stub(:publish!, publish) do
        task.update_attributes(status: 'created')
        replace.verify
        publish.verify

        replace.expect(:call, nil)
        publish.expect(:call, nil)
        task.update_attributes(status: 'complete')
        replace.verify
        publish.verify
      end
    end
  end

  it 'updates the image url on complete' do
    task.image_resource.update_attributes(url: 'what/ever')

    task.update_attributes(status: 'created')
    assert_equal task.image_resource[:url], 'what/ever'
    refute_equal task.image_resource.url, 'what/ever'
    assert_equal task.image_resource.url, task.image_resource.original_url

    task.update_attributes(status: 'complete')
    refute_equal task.image_resource[:url], 'what/ever'
    assert_equal task.image_resource[:url], task.image_resource.published_url
    refute_equal task.image_resource.url, 'what/ever'
    assert_equal task.image_resource.url, task.image_resource.published_url
  end
end
