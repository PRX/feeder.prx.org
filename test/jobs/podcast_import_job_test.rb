require 'test_helper'
require 'minitest/mock'

describe PodcastImportJob do

  let(:job) { PodcastImportJob.new }

  it 'import that podcast' do
    importer = MiniTest::Mock.new
    importer.expect(:import_series!, true)
    importer.expect(:import_episodes!, true)
    job.perform(importer).must_equal true
  end

  it 'can skip importing the series' do
    importer = MiniTest::Mock.new
    importer.expect(:import_episodes!, true)
    job.perform(importer, import_series = false).must_equal true
  end

end
