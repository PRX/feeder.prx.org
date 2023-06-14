require "test_helper"

describe SeriesUpdateWorker do
  let(:podcast) { create(:podcast, prx_uri: "/api/v1/series/20829") }

  let(:profile) { "https://cms-staging.prx.tech/pub/d754c711890d7b7a57a43a432dd79137/0/web/series_image/15407/original/mothradiohr-whitelogo.jpg" }

  let(:body) { json_file(:prx_series) }

  let(:msg) do
    {
      message_id: "this-is-a-message-id-guid",
      app: "cms",
      sent_at: 1.second.ago.utc.iso8601(3),
      subject: "series",
      action: "update",
      body: JSON.parse(body)
    }
  end

  let(:worker) do
    SeriesUpdateWorker.new
  end

  before do
    stub_request(:get, "https://cms.prx.org/api/v1/series/149726")
      .with(headers: {"Accept" => "application/json"})
      .to_return(status: 200, body: body, headers: {})
  end

  it "creates a series resource" do
    series = worker.api_resource(JSON.parse(body).with_indifferent_access)
    assert_instance_of PrxAccess::PrxHyperResource, series
  end

  it "can update a podcast" do
    podcast.stub(:copy_media, true) do
      lbd = podcast.last_build_date
      uat = podcast.updated_at
      Podcast.stub(:by_prx_series, podcast) do
        worker.perform(nil, msg)
        assert_operator worker.podcast.last_build_date, :>, lbd
        assert_operator worker.podcast.updated_at, :>, uat
      end
    end
  end

  it "will not update a deleted podcast" do
    podcast = create(:podcast, prx_uri: "/api/v1/series/32832", deleted_at: Time.now)
    assert podcast.deleted?
    podcast.stub(:copy_media, true) do
      Podcast.stub(:by_prx_series, podcast) do
        worker.perform(nil, msg)
        assert worker.podcast.deleted?
      end
    end
  end

  it "can delete an podcast" do
    podcast = create(:podcast, prx_uri: "/api/v1/series/32832")
    Podcast.stub(:by_prx_series, podcast) do
      worker.perform(nil, msg.tap { |m| m[:action] = "delete" })
      refute_nil worker.podcast.deleted_at
    end
  end
end
