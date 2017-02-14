require 'test_helper'

describe PodcastImportJob do

  let(:job) { PodcastImportJob.new }

  it 'import that podcast' do
    job.perform('', '')
  end
end
