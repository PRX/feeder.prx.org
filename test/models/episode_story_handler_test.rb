require "test_helper"
require "prx_access"

describe EpisodeStoryHandler do
  include PrxAccess

  let(:episode) { create(:episode) }

  let(:story) do
    msg = json_file(:prx_story_all)
    body = JSON.parse(msg)
    href = body.dig(:_links, :self, :href)
    resource = PrxAccess::PrxHyperResource.new(root: "https://cms.prx.org/api/vi/")
    link = PrxAccess::PrxHyperResource::Link.new(resource, href: href)
    PrxAccess::PrxHyperResource.new_from(body: body, resource: resource, link: link)
  end

  it "can be created from a story" do
    create(:podcast, prx_uri: "/api/v1/series/36501")
    episode = EpisodeStoryHandler.create_from_story!(story)
    assert_equal episode.explicit, "false"
    refute_nil episode
    refute_nil episode.published_at
    assert_equal episode.published_at, Time.parse(story.attributes[:published_at])
    refute_nil episode.released_at
    assert_equal episode.released_at, Time.parse(story.attributes[:released_at])
    first_audio = episode.contents.first.original_url
    last_audio = episode.contents.last.original_url
    assert_equal first_audio, "s3://mediajoint.production.prx.org/public/audio_files/1200648/lcs_spring16_act1.mp3"
    assert_equal last_audio, "s3://mediajoint.production.prx.org/public/audio_files/1200657/broadcast/t01.mp3"
    assert_equal episode.description, "this is a description"
    assert_equal episode.season_number, 2
    assert_equal episode.episode_number, 4
    assert_equal episode.clean_title, "Stripped-down title"
    assert_equal episode.production_notes, "Some production notes"
    assert_equal episode.prx_audio_version_uri, "/api/v1/audio_versions/35397"
    assert_equal episode.audio_version, "Audio Version"
    assert_equal episode.segment_count, 4

    # should have one unprocessed image
    assert_nil episode.ready_image
    assert_equal 1, episode.images.count
    assert_equal episode.images.first, episode.image
    assert_equal "created", episode.image.status
    assert_equal "transistor1400.jpg", episode.image.file_name
    assert_equal "some-caption", episode.image.caption
    assert_equal "some-credit", episode.image.credit
  end

  it "does not replace contents with the same original_url" do
    create(:podcast, prx_uri: "/api/v1/series/36501")
    episode = EpisodeStoryHandler.create_from_story!(story)

    assert_equal 4, episode.contents.with_deleted.count

    handler = EpisodeStoryHandler.new(episode)
    handler.update_from_story!(story)

    assert_equal 4, episode.reload.contents.with_deleted.count
  end

  describe "with episode identifiers" do
    let(:zero_identifiers_story) do
      msg = json_file(:prx_story_zero_identifiers)
      body = JSON.parse(msg)
      href = body.dig(:_links, :self, :href)
      resource = PrxAccess::PrxHyperResource.new(root: "https://cms.prx.org/api/vi/")
      link = PrxAccess::PrxHyperResource::Link.new(resource, href: href)
      PrxAccess::PrxHyperResource.new_from(body: body, resource: resource, link: link)
    end

    let(:invalid_identifiers_story) do
      msg = json_file(:prx_story_invalid_identifiers)
      body = JSON.parse(msg)
      href = body.dig(:_links, :self, :href)
      resource = PrxAccess::PrxHyperResource.new(root: "https://cms.prx.org/api/vi/")
      link = PrxAccess::PrxHyperResource::Link.new(resource, href: href)
      PrxAccess::PrxHyperResource.new_from(body: body, resource: resource, link: link)
    end

    it "sets episode and season numbers from identifiers" do
      create(:podcast, prx_uri: "/api/v1/series/36501")
      episode = EpisodeStoryHandler.create_from_story!(story)
      assert_equal episode.season_number, 2
      assert_equal episode.episode_number, 4
    end

    it "wont use string identifiers" do
      create(:podcast, prx_uri: "/api/v1/series/32165")
      episode = EpisodeStoryHandler.create_from_story!(invalid_identifiers_story)
      assert_nil episode.season_number
      assert_nil episode.episode_number
    end

    it "does not allow identifiers to be zero" do
      create(:podcast, prx_uri: "/api/v1/series/32164")
      episode = EpisodeStoryHandler.create_from_story!(zero_identifiers_story)
      assert_nil episode.season_number
      assert_nil episode.episode_number
    end

    it "blanks out identifiers on update" do
      create(:podcast, prx_uri: "/api/v1/series/36501")
      episode = EpisodeStoryHandler.create_from_story!(story)
      assert_operator episode.season_number, :>, 0
      assert_operator episode.episode_number, :>, 0
      EpisodeStoryHandler.new(episode).update_from_story(zero_identifiers_story)
      assert_nil episode.season_number
      assert_nil episode.episode_number
    end
  end
end
