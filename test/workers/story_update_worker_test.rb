require "test_helper"

describe StoryUpdateWorker do
  let(:podcast) { create(:podcast, prx_uri: "/api/v1/series/20829") }
  let(:prx_story_update) { json_file(:prx_story_updates) }
  let(:prx_story_id) { 149726 }
  let(:prx_story_deleted) { json_file(:prx_story_deleted) }
  let(:real_story_update) { json_file(:this_is_love) }
  let(:real_story_id) { 235196 }
  let(:msg) { {subject: "story", action: "update", body: prx_story_update, sent_at: 1.second.ago} }
  let(:worker) { StoryUpdateWorker.new }

  before do
    stub_request(:get, "https://cms.prx.org/api/v1/authorization/stories/#{prx_story_id}")
      .with(headers: {"Accept" => "application/json"})
      .to_return(status: 200, body: prx_story_update, headers: {})

    stub_request(:get, "https://cms.prx.org/api/v1/authorization/stories/#{real_story_id}")
      .with(headers: {"Accept" => "application/json"})
      .to_return(status: 200, body: real_story_update, headers: {})

    stub_request(:get, "https://cms.prx.org/api/v1/authorization/stories/99999")
      .with(headers: {"Accept" => "application/json"})
      .to_return(status: 400, body: '{"status":404,"message":"Resource Not Found"}', headers: {})
  end

  it "creates a story resource" do
    refute_nil prx_story_update
    story_update_message = JSON.parse(prx_story_update).with_indifferent_access
    story = worker.api_resource(story_update_message)
    assert_instance_of PrxAccess::PrxHyperResource, story
  end

  it "can create an episode" do
    refute_nil podcast
    mock_episode = Minitest::Mock.new
    mock_episode.expect(:copy_media, true)
    mock_episode.expect(:podcast, podcast)
    EpisodeStoryHandler.stub(:create_from_story!, mock_episode) do
      podcast.stub(:copy_media, true) do
        worker.stub(:get_account_token, "token") do
          worker.perform(nil, {subject: "story", action: "update", body: JSON.parse(prx_story_update)})
        end
      end
    end
  end

  it "can update an episode" do
    episode = create(:episode, prx_uri: "/api/v1/stories/#{real_story_id}", podcast: podcast)
    episode.stub(:copy_media, true) do
      episode.stub(:podcast, podcast) do
        episode.podcast.stub(:copy_media, true) do
          Episode.stub(:by_prx_story, episode) do
            worker.stub(:get_account_token, "token") do
              lbd = episode.podcast.last_build_date
              uat = episode.updated_at
              bod = JSON.parse(real_story_update)
              worker.perform(nil, {subject: "story", action: "update", body: bod})
              assert_equal worker.episode.prx_uri, "/api/v1/stories/#{real_story_id}"
              assert_operator worker.episode.podcast.last_build_date, :>, lbd
              assert_operator worker.episode.updated_at, :>, uat
            end
          end
        end
      end
    end
  end

  it "will not update a deleted episode" do
    episode = create(:episode, prx_uri: "/api/v1/stories/#{prx_story_id}", podcast: podcast, deleted_at: Time.now)
    assert episode.deleted?
    podcast.stub(:copy_media, true) do
      episode.stub(:copy_media, true) do
        episode.stub(:podcast, podcast) do
          Episode.stub(:by_prx_story, episode) do
            worker.stub(:get_account_token, "token") do
              worker.perform(nil, {subject: "story", action: "update", body: JSON.parse(prx_story_update)})
              assert worker.episode.deleted?
            end
          end
        end
      end
    end
  end

  it "will not update via a deleted story" do
    episode = create(:episode, prx_uri: "/api/v1/stories/#{prx_story_id}", podcast: podcast, deleted_at: Time.now)
    assert episode.deleted?
    podcast.stub(:copy_media, true) do
      episode.stub(:copy_media, true) do
        episode.stub(:podcast, podcast) do
          worker.stub(:get_account_token, "token") do
            worker.stub(:get_story, ->(_) { raise HyperResource::ClientError.new("404", {body: "Resource Not Found", response: "Gone!"}) }) do
              assert_equal :gone, worker.perform(nil, {subject: "story", action: "update", body: JSON.parse(prx_story_update)})
            end
          end
        end
      end
    end
  end

  it "can delete an episode" do
    episode = create(:episode, prx_uri: "/api/v1/stories/99999", podcast: podcast)
    Episode.stub(:by_prx_story, episode) do
      episode.stub(:podcast, podcast) do
        worker.stub(:get_account_token, "token") do
          worker.perform(nil, {subject: "story", action: "delete", body: JSON.parse(prx_story_deleted)})
          refute_nil worker.episode.deleted_at
        end
      end
    end
  end

  describe "with an invalid story" do
    let(:invalid_story_update) { json_file(:prx_invalid_story_updates) }
    let(:invalid_story_id) { 149727 }

    let(:invalid_update_msg) do
      {
        subject: "story",
        action: "update",
        body: invalid_story_update,
        sent_at: 1.second.ago
      }
    end
    let(:invalid_update_job) do
      StoryUpdateWorker.new.tap do |j|
        j.message = invalid_update_msg
      end
    end

    before do
      stub_request(:get, "https://cms.prx.org/api/v1/authorization/stories/#{invalid_story_id}")
        .with(headers: {"Accept" => "application/json"})
        .to_return(status: 200, body: invalid_story_update, headers: {})
    end

    it "wont accept an invalid story on update" do
      episode = create(:episode, prx_uri: "/api/v1/stories/#{invalid_story_id}", podcast: podcast)
      episode.stub(:copy_media, true) do
        episode.stub(:podcast, podcast) do
          Episode.stub(:by_prx_story, episode) do
            worker.stub(:get_account_token, "token") do
              lbd = episode.podcast.last_build_date
              uat = episode.updated_at
              worker.perform(nil, {subject: "story", action: "update", body: invalid_story_update})
              refute_operator episode.podcast.last_build_date, :>, lbd
              refute_operator episode.updated_at, :>, uat
            end
          end
        end
      end
    end

    it "will accept an invalid story on unpublish" do
      episode = create(:episode, prx_uri: "/api/v1/stories/#{invalid_story_id}", podcast: podcast)
      episode.stub(:copy_media, true) do
        episode.stub(:podcast, podcast) do
          episode.podcast.stub(:copy_media, true) do
            Episode.stub(:by_prx_story, episode) do
              worker.stub(:get_account_token, "token") do
                lbd = episode.podcast.last_build_date
                uat = episode.updated_at
                worker.perform(nil, {subject: "story", action: "unpublish", body: invalid_story_update})
                refute worker.episode.published?
                assert_operator worker.episode.podcast.last_build_date, :>, lbd
                assert_operator worker.episode.updated_at, :>, uat
              end
            end
          end
        end
      end
    end
  end
end
