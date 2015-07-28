require 'test_helper'

describe EpisodesController do
  let(:podcast) { create(:podcast) }

  describe '#create' do
    it 'creates a new episode from a PRX ID' do

      podcast.stub(:create_publish_task, true) do
        Podcast.stub(:find_by, podcast) do
          post(:create, {
            episode: {
              prx_uri: 87683,
              overrides: {
                title: 'Virginity & Fidelity'
              }
            },
            podcast: {
              prx_uri: podcast.prx_uri
            }
          })
        end
      end

      episode = Episode.find_by(prx_uri: 87683)

      episode.wont_be :nil?
      episode.podcast.must_equal podcast
      episode.overrides['title'].must_equal 'Virginity & Fidelity'
    end
  end

  describe '#edit' do
    it 'edits the episode overrides' do
      @episode = create(:episode, podcast: podcast)

      podcast.stub(:create_publish_task, true) do
        Episode.stub(:find, @episode) do
          patch(:update, {
            id: @episode.id,
            episode: {
              overrides: {
                title: 'New Title'
              }
            }
          })
        end
      end

      @episode.reload

      @episode.overrides["title"].must_equal 'New Title'
    end
  end

  describe 'undelete' do
    it 'restores a deleted episode' do
      @episode = create(:episode, podcast: podcast, deleted_at: Time.now)
      @ep_count = Episode.unscoped.count

      podcast.stub(:create_publish_task, true) do
        Podcast.stub(:find_by, podcast) do
          post(:create, {
            episode: {
              prx_uri: @episode.prx_uri,
              overrides: {
                title: 'Virginity & Fidelity'
              }
            },
            podcast: {
              prx_uri: podcast.prx_uri
            }
          })
        end
      end

      @episode.reload
      @episode.wont_be :deleted?
      Episode.unscoped.count.must_equal @ep_count
    end
  end
end
