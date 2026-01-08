require "test_helper"

describe HttpHeadValidator do
  let(:stream) { build_stubbed(:stream_recording) }

  around do |test|
    HttpHeadValidator.stub(:skip_validation?, false) { test.call }
  end

  it "lets other validators handle blank/bad urls" do
    refute stream.url_changed?
    assert stream.valid?

    stream.url = nil
    refute stream.valid?
    assert stream.errors.added?(:url, :blank)

    stream.url = "not-a-url"
    refute stream.valid?
    assert stream.errors.added?(:url, :not_http_url)
  end

  it "validates 200s and content types" do
    stream.url = "http://some.where/1"
    stub_request(:head, stream.url).to_return(status: 200, headers: {content_type: "audio/aac"})
    assert stream.valid?

    stream.url = "http://some.where/2"
    stub_request(:head, stream.url).to_return(status: 200, headers: {content_type: "text/plain"})
    refute stream.valid?
    assert stream.errors.added?(:url, :invalid_content_type)

    stream.url = "http://some.where/3"
    stub_request(:head, stream.url).to_return(status: 404)
    refute stream.valid?
    assert stream.errors.added?(:url, :unreachable)

    stream.url = "http://some.where/4"
    stub_request(:head, stream.url).to_return(status: 302, headers: {location: "http://some.where/5"})
    stub_request(:head, "http://some.where/5").to_return(status: 200, headers: {content_type: "audio/mpeg"})
    assert stream.valid?
  end
end
