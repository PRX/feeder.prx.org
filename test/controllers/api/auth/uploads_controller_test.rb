require "test_helper"

describe Api::Auth::UploadsController do
  let(:json) { JSON.parse(response.body).with_indifferent_access }
  let(:scopes) { ["feeder:episode"] }
  let(:token) { StubToken.new(1234, scopes) }

  before do
    class << @controller; attr_accessor :prx_auth_token; end
    @controller.prx_auth_token = token
    ENV["UPLOAD_BUCKET_PREFIX"] = "uploads"
  end

  it "returns signed urls" do
    mock = Minitest::Mock.new

    mock.expect(:presigned_request, ["some-url1"]) do |method, args = {}|
      assert_equal :put_object, method
      assert_equal ENV["UPLOAD_BUCKET_NAME"], args[:bucket]
      assert_equal false, args[:use_accelerate_endpoint]
      assert_equal 3600, args[:expires_in]
      assert_match(/^uploads\/#{Date.utc_today}\/[0-9a-f-]+\/foo.mp3$/, args[:key])
      true
    end

    mock.expect(:presigned_request, ["some-url2"]) do |method, args = {}|
      assert_equal :get_object, method
      assert_equal ENV["UPLOAD_BUCKET_NAME"], args[:bucket]
      assert_equal false, args[:use_accelerate_endpoint]
      assert_equal 3600, args[:expires_in]
      assert_match(/^uploads\/#{Date.utc_today}\/[0-9a-f-]+\/foo.mp3$/, args[:key])
      true
    end

    Api::Auth::UploadsController.stub(:s3_signer, mock) do
      get :show, params: {api_version: "v1", filename: "foo.mp3"}
      assert_response :success
      assert json[:originalUrl].starts_with?("s3://")
      assert json[:originalUrl].ends_with?("/foo.mp3")
      assert_equal "some-url1", json[:_links]["prx:upload"][:href]
      assert_equal "some-url2", json[:_links]["prx:download"][:href]
    end
  end

  describe "without any write scope" do
    let("scopes") { ["feeder:read-private"] }

    it "returns unauthorized" do
      get :show, params: {api_version: "v1", filename: "foo.mp3"}
      assert_response :unauthorized
    end
  end
end
