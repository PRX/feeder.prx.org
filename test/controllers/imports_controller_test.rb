require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  setup_current_user { build(:user, account_id: 123) }
  setup { @podcast = create(:podcast, prx_account_uri: "/api/v1/accounts/123") }

  before do
    stub_requests
  end

  let(:feed) { Feedjira.parse(test_file("/fixtures/transistor_two.xml")) }
  let(:import_1) { PodcastImport.create(podcast: @podcast, url: feed.url) }
  let(:params) { {url: feed.url} }

  test "should get index" do
    get podcast_imports_url(@podcast)
    assert_response :success
  end

  test "authorizes index" do
    @podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_imports_url(@podcast)
    assert_response :forbidden
  end

  test "should show import" do
    get podcast_import_url(@podcast, import_1)
    assert_response :success
  end

  test "authorizes show" do
    @podcast.update(prx_account_uri: "/api/v1/accounts/456")
    get podcast_import_url(@podcast, import_1)
    assert_response :forbidden
  end

  test "should create import" do
    assert_difference("PodcastImport.count") do
      post podcast_imports_url(@podcast), params: {podcast_import: params}
    end

    assert_redirected_to podcast_imports_url(@podcast)
  end

  test "authorizes creating imports" do
    @podcast.update(prx_account_uri: "/api/v1/accounts/456")
    post podcast_imports_url(@podcast), params: {podcast_import: params}
    assert_response :forbidden
  end

  # test "validates creating imports" do
  #   post podcast_imports_url(@podcast), params: {podcast_import: {url: nil}}
  #   assert_response :unprocessable_entity
  # end

  def stub_requests
    stub_request(:get, "https://transistor.prx.org")
      .with(
        headers: {
          "Accept" => "*/*",
          "Host" => "transistor.prx.org:443",
          "User-Agent" => "PRX CMS FeedValidator"
        }
      )
      .to_return(status: 200, body: test_file("/fixtures/transistor_two.xml"))
  end
end
