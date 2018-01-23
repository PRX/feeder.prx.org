require 'test_helper'

class TestImportUtilsModel
  include ImportUtils
end

describe TestImportUtilsModel do
  let(:model) { TestImportUtilsModel.new }
  let(:emoticons) { "😀😁😂😃😄😅😆😇😈😉😊😋😌😍😎😏😐😑😒😓😔😕😖😗😘😙😚😛😜😝😞😟😠😡😢😣😤😥😦😧😨😩😪😫😬😭😮😯😰😱😲😳😴😵😶😷😸😹😺😻😼😽😾😿🙀🙁🙂🙅🙆🙇🙈🙉🙊🙋🙌🙍🙎🙏" }

  it 'filters out 4 byte utf 8, but leaves other utf chars alone' do
    model.clean_text("Hi!🌈").must_equal("Hi!") # from tumble
    model.clean_text("Kayla Briët").must_equal("Kayla Briët") # from TED feed

    # h/t https://github.com/maximeg/activecleaner/blob/master/spec/lib/active_cleaner/utf8mb4_cleaner_spec.rb
    model.clean_text("emotions!#{emoticons}").must_equal("emotions!")
    model.clean_text("L'Inouï Goûter À Manger.").must_equal("L'Inouï Goûter À Manger.")
    model.clean_text("ginkō is written as 銀行").must_equal("ginkō is written as 銀行")
  end
end
