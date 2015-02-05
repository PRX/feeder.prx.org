require 'test_helper'

describe EventResponder do
  before do
    Timecop.freeze(Time.local(2015, 2, 2))

    @podcast = create(:podcast)
    @episode = create(:episode, podcast: @podcast)
  end

  after do
    @podcast.reload
    @podcast.last_build_date.must_equal Time.now
    @podcast.pub_date.must_equal Time.now

    Timecop.return
  end

  it 'removes an episode' do
    EventResponder.remove(@episode.prx_id)

    @podcast.episodes.wont_include @episode
  end

  it 'regenerates feed when episode is edited' do
    EventResponder.edit(@episode.prx_id)

    @episode.updated_at.must_equal Time.now
  end
end
