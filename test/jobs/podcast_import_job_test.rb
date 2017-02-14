require 'test_helper'

describe PodcastImportJob do

  let(:account_path) { '/api/v1/accounts/8' }
  let(:podcast_url) { 'http://feeds.prx.org/transistor_stem' }
  let(:job) { PodcastImportJob.new }

  it 'import that podcast' do
    job.stub(:import_podcast, true) do
      job.perform(account_path, podcast_url).must_equal true
    end
  end
end
