require "test_helper"

class ImportUtilsTest < ActiveSupport::TestCase
  let(:model) { PodcastImport.new }
  let(:emoticons) { "😀😁😂😃😄😅😆😇😈😉😊😋😌😍😎😏😐😑😒😓😔😕😖😗😘😙😚😛😜😝😞😟😠😡😢😣😤😥😦😧😨😩😪😫😬😭😮😯😰😱😲😳😴😵😶😷😸😹😺😻😼😽😾😿🙀🙁🙂🙅🙆🙇🙈🙉🙊🙋🙌🙍🙎🙏" }

  it "leaves utf chars alone" do
    _(model.clean_text("Hi!🌈")).must_equal("Hi!🌈") # from tumble
    _(model.clean_text("Kayla Briët")).must_equal("Kayla Briët") # from TED feed

    # h/t https://github.com/maximeg/activecleaner/blob/master/spec/lib/active_cleaner/utf8mb4_cleaner_spec.rb
    _(model.clean_text("emotions!#{emoticons}")).must_equal("emotions!#{emoticons}")
    _(model.clean_text("L'Inouï Goûter À Manger.")).must_equal("L'Inouï Goûter À Manger.")
    _(model.clean_text("ginkō is written as 銀行")).must_equal("ginkō is written as 銀行")
  end

  it "cleans up urls" do
    _(model.clean_url("example.com")).must_equal("https://example.com")
    _(model.clean_url("//example.com")).must_equal("https://example.com")
    _(model.clean_url("http://example.com")).must_equal("http://example.com")
    _(model.clean_url("https://example.com")).must_equal("https://example.com")
    _(model.clean_url(nil)).must_be_nil
    _(model.clean_url("")).must_be_nil
    _(model.clean_url(URI.parse("https://example.com"))).must_equal("https://example.com")
  end

  it "converts yes/no to boolean" do
    _(model.clean_yes_no("yes")).must_equal true
    _(model.clean_yes_no("true")).must_equal true
    _(model.clean_yes_no("1")).must_equal true
    _(model.clean_yes_no("no")).must_equal false
    _(model.clean_yes_no("false")).must_equal false
    _(model.clean_yes_no("0")).must_equal false
    _(model.clean_yes_no("foo")).must_equal false
    _(model.clean_yes_no(nil)).must_equal false
    _(model.clean_yes_no("")).must_equal false
  end

  it "does not truncate titles" do
    acceptable_title = "a" * 256
    _(model.clean_title(acceptable_title).length).must_equal 256
  end

  describe "#download_file" do
    let(:io) { StringIO.new }
    let(:url) { "https://storage.googleapis.com/bucket/object?GoogleAccessId=a%40b.com&Expires=1&Signature=a%2Bb%3D" }

    it "keeps the query string for signed urls" do
      stub_request(:get, url).to_return(status: 200, body: "audio")

      model.download_file(io, url)
      _(io.string).must_equal "audio"
    end

    it "appends to the io" do
      stub_request(:get, url).to_return(status: 200, body: "audio")

      io.write("first")
      model.download_file(io, url)
      _(io.string).must_equal "firstaudio"
    end

    it "follows absolute and relative redirects" do
      stub_request(:get, "http://example.com/a.mp3").to_return(status: 301, headers: {location: "https://example.com/b.mp3"})
      stub_request(:get, "https://example.com/b.mp3").to_return(status: 302, headers: {location: "/c.mp3?x=1"})
      stub_request(:get, "https://example.com/c.mp3?x=1").to_return(status: 200, body: "audio")

      model.download_file(io, "http://example.com/a.mp3")
      _(io.string).must_equal "audio"
    end

    it "raises on too many redirects" do
      stub_request(:get, "https://example.com/a.mp3").to_return(status: 302, headers: {location: "/a.mp3"})

      err = assert_raises(ImportUtils::HttpError) { model.download_file(io, "https://example.com/a.mp3") }
      _(err.message).must_match(/too many redirects/)
    end

    it "raises on errors without writing the body" do
      stub_request(:get, url).to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")

      err = assert_raises(ImportUtils::HttpError) { model.download_file(io, url) }
      _(err.message).must_match(/403/)
      _(io.string).must_be_empty
    end
  end
end
