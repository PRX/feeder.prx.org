require "test_helper"
require "minitest/mock"

describe EpisodeImportJob do
  let(:job) { EpisodeImportJob.new }

  it "import that episode" do
    episode_import = MiniTest::Mock.new
    episode_import.expect(:import, true)
    job.perform(episode_import).must_equal true
  end
end
