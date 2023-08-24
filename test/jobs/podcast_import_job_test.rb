require "test_helper"
require "minitest/mock"

describe PodcastImportJob do
  let(:job) { PodcastImportJob.new }

  it "import that podcast" do
    importer = Minitest::Mock.new
    importer.expect(:import_podcast!, true)
    importer.expect(:import_episodes!, true)
    _(job.perform(importer)).must_equal true
  end

  it "can skip importing the series" do
    importer = Minitest::Mock.new
    importer.expect(:import_episodes!, true)
    _(job.perform(importer, false)).must_equal true
  end
end
