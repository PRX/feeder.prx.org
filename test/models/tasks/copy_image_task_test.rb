require 'test_helper'

describe Tasks::CopyImageTask do
  let(:task) { create(:copy_image_task) }
  let(:image) { task.owner }

  it 'has task options' do
    opts = task.task_options
    opts[:job_type].must_equal 'file'
    opts[:source].must_equal image.original_url
    opts[:destination].must_match /s3:\/\/test-prx-feed\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/images\/4e745a8c-77ee-481c-a72b-fd868dfd1c9(\d+)\/image\.png/
  end

  it 'gets the image path' do
    task.image_path(image).must_equal "/jjgo/#{image.episode.guid}/images/#{image.guid}/image.png"
  end

  it 'updates status before save' do
    task.status.must_equal 'complete'
    task.image_resource.status.must_equal 'complete'
    task.update_attributes(status: 'processing')
    task.status.must_equal 'processing'
    task.image_resource.status.must_equal 'processing'
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
    task.image_resource[:url].must_equal 'what/ever'
    task.image_resource.url.wont_equal 'what/ever'
    task.image_resource.url.must_equal task.image_resource.original_url

    task.update_attributes(status: 'complete')
    task.image_resource[:url].wont_equal 'what/ever'
    task.image_resource[:url].must_equal task.image_resource.published_url
    task.image_resource.url.wont_equal 'what/ever'
    task.image_resource.url.must_equal task.image_resource.published_url
  end
end
