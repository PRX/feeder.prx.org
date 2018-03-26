require 'test_helper'

describe StoryUpdateJob do

  let(:podcast) { create(:podcast, prx_uri: '/api/v1/series/20829') }

  let(:prx_story_update) { json_file(:prx_story_updates) }
  let(:prx_story_id) { 149726 }
  let(:real_story_update) { json_file(:this_is_love) }
  let(:real_story_id) { 235196 }

  let(:msg) { { subject: 'story', action: 'update', body: prx_story_update, sent_at: 1.second.ago } }

  let(:job) do
    StoryUpdateJob.new.tap do |j|
      j.message = msg
      j.subject = msg[:subject]
      j.action = msg[:action]
    end
  end

  before do
    stub_request(:get, "https://cms.prx.org/api/v1/authorization/stories/#{prx_story_id}").
      with(headers: { 'Accept' => 'application/json' } ).
      to_return(status: 200, body: prx_story_update, headers: {})

    stub_request(:get, "https://cms.prx.org/api/v1/authorization/stories/#{real_story_id}").
      with(headers: { 'Accept' => 'application/json' } ).
      to_return(status: 200, body: real_story_update, headers: {})
  end

  it 'creates a story resource' do
    story = job.api_resource(JSON.parse(prx_story_update).with_indifferent_access)
    story.must_be_instance_of PRXAccess::PRXHyperResource
  end

  it 'can create an episode' do
    podcast.wont_be_nil
    mock_episode = Minitest::Mock.new
    mock_episode.expect(:try, true, [:copy_media])
    mock_episode.expect(:podcast, podcast)
    EpisodeStoryHandler.stub(:create_from_story!, mock_episode) do
      podcast.stub(:copy_media, true) do
        podcast.stub(:create_publish_task, true) do
          job.stub(:get_account_token, 'token') do
            job.perform(subject: 'story', action: 'update', body: JSON.parse(prx_story_update))
          end
        end
      end
    end
  end

  it 'can update an episode' do
    episode = create(:episode, prx_uri: "/api/v1/stories/#{real_story_id}", podcast: podcast)
    episode.stub(:copy_media, true) do
      episode.stub(:podcast, podcast) do
        episode.podcast.stub(:create_publish_task, true) do
          episode.podcast.stub(:copy_media, true) do
            Episode.stub(:by_prx_story, episode) do
              job.stub(:get_account_token, 'token') do
                lbd = episode.podcast.last_build_date
                uat = episode.updated_at
                bod = JSON.parse(real_story_update)
                job.perform(subject: 'story', action: 'update', body: bod)
                job.episode.podcast.last_build_date.must_be :>, lbd
                job.episode.updated_at.must_be :>, uat
              end
            end
          end
        end
      end
    end
  end

  it 'will not update a deleted episode' do
    episode = create(:episode, prx_uri: "/api/v1/stories/#{prx_story_id}", podcast: podcast, deleted_at: Time.now)
    episode.must_be :deleted?
    podcast.stub(:create_publish_task, true) do
      podcast.stub(:copy_media, true) do
        episode.stub(:copy_media, true) do
          episode.stub(:podcast, podcast) do
            Episode.stub(:by_prx_story, episode) do
              job.stub(:get_account_token, 'token') do
                job.perform(subject: 'story', action: 'update', body: JSON.parse(prx_story_update))
                job.episode.must_be :deleted?
              end
            end
          end
        end
      end
    end
  end

  it 'can delete an episode' do
    episode = create(:episode, prx_uri: "/api/v1/stories/#{prx_story_id}", podcast: podcast)
    podcast.stub(:create_publish_task, true) do
      Episode.stub(:by_prx_story, episode) do
        episode.stub(:podcast, podcast) do
          job.stub(:get_account_token, 'token') do
            job.perform(subject: 'story', action: 'delete', body: JSON.parse(prx_story_update))
            job.episode.deleted_at.wont_be_nil
          end
        end
      end
    end
  end

  describe 'with an invalid story' do
    let(:invalid_story_update) { json_file(:prx_invalid_story_updates) }
    let(:invalid_story_id) { 149727 }

    let(:invalid_update_msg) do
      {
        subject: 'story',
        action: 'update',
        body: invalid_story_update,
        sent_at: 1.second.ago
      }
    end
    let(:invalid_update_job) do
      StoryUpdateJob.new.tap do |j|
        j.message = invalid_update_msg
        j.subject = invalid_update_msg[:subject]
        j.action = invalid_update_msg[:action]
      end
    end

    before do
      stub_request(:get, "https://cms.prx.org/api/v1/authorization/stories/#{invalid_story_id}").
        with(headers: { 'Accept' => 'application/json' } ).
        to_return(status: 200, body: invalid_story_update, headers: {})
    end

    it 'wont accept an invalid story on update' do
      episode = create(:episode, prx_uri: "/api/v1/stories/#{invalid_story_id}", podcast: podcast)
      episode.stub(:copy_media, true) do
        episode.stub(:podcast, podcast) do
          episode.podcast.stub(:create_publish_task, true) do
            Episode.stub(:by_prx_story, episode) do
              job.stub(:get_account_token, 'token') do
                lbd = episode.podcast.last_build_date
                uat = episode.updated_at
                job.perform(subject: 'story', action: 'update', body: invalid_story_update)
                episode.podcast.last_build_date.wont_be :>, lbd
                episode.updated_at.wont_be :>, uat
              end
            end
          end
        end
      end
    end

    it 'will accept an invalid story on unpublish' do
      episode = create(:episode, prx_uri: "/api/v1/stories/#{invalid_story_id}", podcast: podcast)
      episode.stub(:copy_media, true) do
        episode.stub(:podcast, podcast) do
          episode.podcast.stub(:create_publish_task, true) do
            episode.podcast.stub(:copy_media, true) do
              Episode.stub(:by_prx_story, episode) do
                job.stub(:get_account_token, 'token') do
                  lbd = episode.podcast.last_build_date
                  uat = episode.updated_at
                  job.perform(subject: 'story', action: 'unpublish', body: invalid_story_update)
                  job.episode.wont_be :published?
                  job.episode.podcast.last_build_date.must_be :>, lbd
                  job.episode.updated_at.must_be :>, uat
                end
              end
            end
          end
        end
      end
    end
  end
end
