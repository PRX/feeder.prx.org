require "test_helper"

describe RedirectPrefixValidator do
  let(:feed) { build_stubbed(:feed, enclosure_prefix: nil) }

  around do |test|
    RedirectPrefixValidator.stub :skip_validation?, false do
      test.call
    end
  end

  it "allows nil/blank" do
    assert feed.valid?

    feed.enclosure_prefix = ""
    assert feed.valid?
  end

  it "follows prefix redirects" do
    one = "https://one.com/track/two.com/redirect.mp3/three.com/123456/dovetail.prxu.org/zero.mp3"
    two = "https://two.com/redirect.mp3/three.com/123456/dovetail.prxu.org/zero.mp3"
    three = "https://three.com/123456/dovetail.prxu.org/zero.mp3"
    four = "https://dovetail.prxu.org/zero.mp3"

    r1 = stub_request(:head, one).to_return(status: 302, headers: {location: two})
    r2 = stub_request(:head, two).to_return(status: 301, headers: {location: three})
    r3 = stub_request(:head, three).to_return(status: 302, headers: {location: four})
    r4 = stub_request(:head, four).to_return(status: 200)

    feed.enclosure_prefix = one.sub("dovetail.prxu.org/zero.mp3", "")
    assert feed.valid?
    assert_requested(r1)
    assert_requested(r2)
    assert_requested(r3)
    assert_requested(r4)
  end

  it "validates successful responses" do
    one = "https://one.com/track/stuff/two.com/redirect/dovetail.prxu.org/zero.mp3"
    two = "https://two.com/redirect/dovetail.prxu.org/zero.mp3"

    stub_request(:head, one).to_return(status: 302, headers: {location: two})
    stub_request(:head, two).to_return(status: 404)

    feed.enclosure_prefix = one.sub("/dovetail.prxu.org/zero.mp3", "")
    assert feed.invalid?
    assert feed.errors.added?(:enclosure_prefix, :unreachable)
  end

  it "validates duplicate https" do
    one = "https://https://two.com/redirect/dovetail.prxu.org/zero.mp3"

    # can't really produce this error via webmock
    WebMock.allow_net_connect!

    feed.enclosure_prefix = one.sub("/dovetail.prxu.org/zero.mp3", "")
    assert feed.invalid?
    assert feed.errors.added?(:enclosure_prefix, :unreachable)

    WebMock.disable_net_connect!
  end

  it "validates bad domains" do
    one = "https://one.com/track/stuff/two.com/redirect/dovetail.prxu.org/zero.mp3"
    two = "https://two.com/redirect/dovetail.prxu.org/zero.mp3"

    stub_request(:head, one).to_return(status: 302, headers: {location: two})
    stub_request(:head, two).to_raise(Socket::ResolutionError)

    feed.enclosure_prefix = one.sub("/dovetail.prxu.org/zero.mp3", "")
    assert feed.invalid?
    assert feed.errors.added?(:enclosure_prefix, :unreachable)
  end

  it "validates too many redirects" do
    one = "https://one.com/track/two.com/redirect.mp3/three.com/123456/dovetail.prxu.org/zero.mp3"
    two = "https://two.com/redirect.mp3/three.com/123456/dovetail.prxu.org/zero.mp3"
    three = "https://three.com/123456/dovetail.prxu.org/zero.mp3"
    four = "https://dovetail.prxu.org/zero.mp3"

    r1 = stub_request(:head, one).to_return(status: 302, headers: {location: two})
    r2 = stub_request(:head, two).to_return(status: 301, headers: {location: three})
    r3 = stub_request(:head, three).to_return(status: 302, headers: {location: four})
    r4 = stub_request(:head, four).to_return(status: 200)

    # override validation options
    feed.enclosure_prefix = one.sub("/dovetail.prxu.org/zero.mp3", "")
    validator = RedirectPrefixValidator.new(attributes: [:enclosure_prefix], max_jumps: 2)
    validator.validate(feed)
    assert feed.errors.added?(:enclosure_prefix, :too_many_redirects)
    assert_requested(r1)
    assert_requested(r2)
    assert_requested(r3)
    assert_requested(r4)
  end
end
