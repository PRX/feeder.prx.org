require "test_helper"

describe FeedToken do
  let(:podcast) { create(:podcast) }
  let(:feed) { podcast.default_feed }
  let(:token1) { FeedToken.create(token: "tok1", feed: feed) }
  let(:token2) { FeedToken.create(token: "tok2", feed: feed) }

  describe ".new" do
    it "sets a default token" do
      str = FeedToken.new.token
      assert str.length >= 20
    end
  end

  describe "#valid?" do
    it "validates unique tokens" do
      assert token1.valid?
      assert token2.valid?

      token2.token = "tok1"
      refute token2.valid?

      token2.feed_id = 999999
      assert token2.valid?
    end

    it "restricts slug characters" do
      ["", "n@-ats", "no/slash", "nospace "].each do |str|
        token1.token = str
        refute token1.valid?
      end
    end
  end
end
