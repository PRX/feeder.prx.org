require "test_helper"

class HttpUtilTest < ActiveSupport::TestCase
  describe ".filter_url" do
    it "filters signed url params" do
      url = "https://storage.googleapis.com/bucket/object?GoogleAccessId=a%40b.com&Expires=1&Signature=a%2Bb%3D&other=1"
      filtered = HttpUtil.filter_url(url)

      _(filtered).must_equal "https://storage.googleapis.com/bucket/object?GoogleAccessId=%5BFILTERED%5D&Expires=1&Signature=%5BFILTERED%5D&other=1"
    end

    it "returns an empty string for blank urls" do
      _(HttpUtil.filter_url(nil)).must_equal ""
      _(HttpUtil.filter_url("")).must_equal ""
    end

    it "leaves urls without a query alone" do
      _(HttpUtil.filter_url("https://example.com/a.mp3")).must_equal "https://example.com/a.mp3"
    end

    it "keeps param order, duplicates, and valueless params" do
      url = "https://example.com/a.mp3?b=1&flag&Signature=secret&b=2"
      _(HttpUtil.filter_url(url)).must_equal "https://example.com/a.mp3?b=1&flag&Signature=%5BFILTERED%5D&b=2"
    end

    it "drops the query from invalid urls" do
      _(HttpUtil.filter_url("https://exa mple.com/a.mp3?Signature=secret")).must_equal "https://exa mple.com/a.mp3"
    end
  end
end
