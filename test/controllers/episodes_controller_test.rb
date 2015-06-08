require 'test_helper'

describe EpisodesController do
  before do
    Timecop.freeze(Time.local(2015, 1, 13))
    @podcast = create(:podcast)
  end

  after do
    @podcast.reload
    @podcast.last_build_date.must_equal Time.now
    @podcast.pub_date.must_equal Time.now

    Timecop.return
  end

  describe '#create' do
    it 'creates a new episode from a PRX ID' do
      post(:create, {
        episode: {
          prx_id: 87683,
          overrides: {
            title: 'Virginity & Fidelity'
          }
        },
        podcast: {
          prx_id: @podcast.prx_id
        }
      })

      episode = Episode.find_by(prx_id: 87683)

      episode.wont_be :nil?
      episode.podcast.must_equal @podcast
      episode.overrides['title'].must_equal 'Virginity & Fidelity'
    end
  end

  describe '#edit' do
    it 'edits the episode overrides' do
      @episode = create(:episode, podcast: @podcast)

      patch(:update, {
        id: @episode.id,
        episode: {
          overrides: {
            title: 'New Title'
          }
        }
      })

      @episode.reload

      @episode.overrides["title"].must_equal 'New Title'
    end
  end

  describe 'undelete' do
    it 'restores a deleted episode' do
      @episode = create(:episode, podcast: @podcast, deleted_at: Time.now)
      @ep_count = Episode.unscoped.count

      post(:create, {
        episode: {
          prx_id: @episode.prx_id,
          overrides: {
            title: 'Virginity & Fidelity'
          }
        },
        podcast: {
          prx_id: @podcast.prx_id
        }
      })

      @episode.reload
      @episode.wont_be :deleted?
      Episode.unscoped.count.must_equal @ep_count
    end
  end
end
