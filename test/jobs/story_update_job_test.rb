require 'test_helper'

describe StoryUpdateJob do

  let(:podcast) { create(:podcast, prx_uri: '/api/v1/series/20829') }

  let(:body) { json_file(:prx_story_updates) }
  let(:msg) { { subject: 'story', action: 'update', body: body, sent_at: 1.second.ago } }

  let(:job) do
    StoryUpdateJob.new.tap do |j|
      j.message = msg
      j.subject = msg[:subject]
      j.action = msg[:action]
    end
  end

  before do
    if use_webmock?
      stub_request(:get, 'https://cms.prx.org/api/v1/stories/149726').
        with(headers: { 'Accept' => 'application/json' } ).
        to_return(status: 200, body: body, headers: {})
    end
  end

  it 'creates a story resource' do
    story = job.api_resource(JSON.parse(body).with_indifferent_access)
    story.must_be_instance_of PRXAccess::PRXHyperResource
  end

  it 'can create an episode' do
    podcast.wont_be_nil
    mock_episode = Minitest::Mock.new
    mock_episode.expect(:try, true, [:copy_media])
    mock_episode.expect(:podcast, podcast)
    EpisodeStoryHandler.stub(:create_from_story!, mock_episode) do
      podcast.stub(:create_publish_task, true) do
        job.perform(subject: 'story', action: 'update', body: JSON.parse(body))
      end
    end
  end

  it 'can update an episode' do
    episode = create(:episode, prx_uri: '/api/v1/stories/149726', podcast: podcast)
    episode.stub(:copy_media, true) do
      episode.stub(:podcast, podcast) do
        episode.podcast.stub(:create_publish_task, true) do
          Episode.stub(:by_prx_story, episode) do
            lbd = episode.podcast.last_build_date
            uat = episode.updated_at
            job.perform(subject: 'story', action: 'update', body: JSON.parse(body))
            job.episode.podcast.last_build_date.must_be :>, lbd
            job.episode.updated_at.must_be :>, uat
          end
        end
      end
    end
  end

  it 'wont update an episode to become invalid unless its to unpublish' do
    episode = create(:episode, prx_uri: '/api/v1/stories/149726', podcast: podcast, status: 'invalid')

    # MORE HERE
    episode.stub(:copy_media, true) do
      episode.stub(:podcast, podcast) do
        episode.podcast.stub(:create_publish_task, true) do
          Episode.stub(:by_prx_story, episode) do
            lbd = episode.podcast.last_build_date
            uat = episode.updated_at
            job.perform(subject: 'story', action: 'update', body: JSON.parse(body))
            job.episode.podcast.last_build_date.must_be :>, lbd
            job.episode.updated_at.must_be :>, uat
          end
        end
      end
    end
  end

  it 'can update a deleted episode' do
    episode = create(:episode, prx_uri: '/api/v1/stories/149726', podcast: podcast, deleted_at: Time.now)
    episode.must_be :deleted?
    podcast.stub(:create_publish_task, true) do
      episode.stub(:copy_media, true) do
        episode.stub(:podcast, podcast) do
          Episode.stub(:by_prx_story, episode) do
            job.perform(subject: 'story', action: 'update', body: JSON.parse(body))
            job.episode.wont_be :deleted?
          end
        end
      end
    end
  end

  it 'can delete an episode' do
    episode = create(:episode, prx_uri: '/api/v1/stories/149726', podcast: podcast)
    podcast.stub(:create_publish_task, true) do
      Episode.stub(:by_prx_story, episode) do
        episode.stub(:podcast, podcast) do
          job.perform(subject: 'story', action: 'delete', body: JSON.parse(body))
          job.episode.deleted_at.wont_be_nil
        end
      end
    end
  end
end
