require 'test_helper'

describe Tasks::CopyImageTask do
  let(:task) { create(:copy_image_task) }
  let(:image) { task.owner }
  let(:cache_control) { 'x-fixer-Cache-Control=max-age%3D86400' }
  let(:query_str) { "x-fixer-public=true&#{cache_control}" }

  it 'can start the job' do
    Task.stub :new_fixer_sqs_client, SqsMock.new(123) do
      task.start!
      task.job_id.must_equal '123'
    end
  end

  it 'gets the options for fixer copy' do
    opts = task.task_options
    opts[:job_type].must_equal 'file'
    opts[:source].must_equal image.original_url
    opts[:destination].must_match /s3:\/\/test-prx-feed\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/images\/4e745a8c-77ee-481c-a72b-fd868dfd1c9(\d+)\/image\.png/
    opts[:destination].split('?').last.must_equal query_str
  end

  it 'gets the image path' do
    task.image_path(image).must_equal "/jjgo/#{image.episode.guid}/images/#{image.guid}/image.png"
  end

  it 'updates the image on complete' do
    podcast = Minitest::Mock.new
    podcast.expect(:publish!, true)
    image_resource = Minitest::Mock.new

    image_resource.expect('!', false)
    image_resource.expect(:update_attribute, true, [Symbol, String])
    image_resource.expect(:update_from_fixer, true, [Hash])
    image_resource.expect(:url, 'http://image.url/image.png')
    image_resource.expect(:try, image_resource, [:episode])
    image_resource.expect(:try, podcast, [:podcast])
    task.stub(:image_resource, image_resource) do
      task.task_status_changed({}, 'complete')
    end
  end
end
