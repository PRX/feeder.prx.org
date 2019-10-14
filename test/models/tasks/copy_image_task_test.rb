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

  it 'updates the image on complete' do
    podcast = Minitest::Mock.new
    podcast.expect(:publish!, true)
    image_resource = Minitest::Mock.new

    image_resource.expect('!', false)
    image_resource.expect(:update_attribute, true, [Symbol, String])
    image_resource.expect(:url, 'http://image.url/image.png')
    image_resource.expect(:try, image_resource, [:episode])
    image_resource.expect(:try, podcast, [:podcast])
    task.stub(:image_resource, image_resource) do
      task.update_attributes(status: 'complete')
      # TODO: why do these fail?
      # podcast.verify
      # image_resource.verify
    end
  end
end
