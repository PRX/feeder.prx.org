require "test_helper"

class TestImportUtilsModel
  include ImportUtils
end

describe TestImportUtilsModel do
  let(:model) { TestImportUtilsModel.new }
  let(:emoticons) { "😀😁😂😃😄😅😆😇😈😉😊😋😌😍😎😏😐😑😒😓😔😕😖😗😘😙😚😛😜😝😞😟😠😡😢😣😤😥😦😧😨😩😪😫😬😭😮😯😰😱😲😳😴😵😶😷😸😹😺😻😼😽😾😿🙀🙁🙂🙅🙆🙇🙈🙉🙊🙋🙌🙍🙎🙏" }

  it "leaves utf chars alone" do
    _(model.clean_text("Hi!🌈")).must_equal("Hi!🌈") # from tumble
    _(model.clean_text("Kayla Briët")).must_equal("Kayla Briët") # from TED feed

    # h/t https://github.com/maximeg/activecleaner/blob/master/spec/lib/active_cleaner/utf8mb4_cleaner_spec.rb
    _(model.clean_text("emotions!#{emoticons}")).must_equal("emotions!#{emoticons}")
    _(model.clean_text("L'Inouï Goûter À Manger.")).must_equal("L'Inouï Goûter À Manger.")
    _(model.clean_text("ginkō is written as 銀行")).must_equal("ginkō is written as 銀行")
  end

  it "does not truncate titles less or equal to 255 chars length" do
    limit_title = "a" * 255
    _(model.clean_title(limit_title).length).must_equal 255

    less_than_title = "a" * 254
    _(model.clean_title(less_than_title).length).must_equal 254

    short_string = "asdf"
    _(model.clean_title(short_string)).must_equal "asdf"
  end

  it "truncates titles greater than 255 chars" do
    acceptable_title = "a" * 256
    _(model.clean_title(acceptable_title).length).must_equal 255
  end
end
