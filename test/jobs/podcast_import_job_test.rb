require 'test_helper'
require 'minitest/mock'

describe PodcastImportJob do

  let(:job) { PodcastImportJob.new }

  it 'import that podcast' do
    importer = MiniTest::Mock.new
    importer.expect(:import, true)
    job.perform(importer).must_equal true
  end
end
