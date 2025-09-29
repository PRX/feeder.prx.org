require "test_helper"

describe ImportUtils do
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
end
