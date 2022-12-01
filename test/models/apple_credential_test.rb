require 'test_helper'

describe AppleCredential do
  describe '#valid?' do
    it 'requires a podcast or an account uri' do
      p = create(:podcast)

      c1 = build(:apple_credential, podcast: p)
      assert c1.valid?

      c2 = build(:apple_credential, prx_account_uri: '/some/uri')
      assert c2.valid?

      c3 = build(:apple_credential, podcast: nil, prx_account_uri: nil)
      refute c3.valid?

      c4 = build(:apple_credential, podcast: p, prx_account_uri: '/some/uri')
      refute c4.valid?
      assert_includes(c4.errors[:prx_account_uri], "can't set both account uri and podcast")
    end

    it 'requires apple key fields' do
      p = create(:podcast)
      c = build(:apple_credential, podcast: p)
      assert c.valid?

      c.apple_key_id = nil
      refute c.valid?

      c.apple_key_id = "pears are better"
      c.apple_key_pem_b64 = nil
      refute c.valid?
    end

    it 'is unique to a podcast' do
      c1 = build(:apple_credential, podcast: p, podcast_id: 'foo')
      c2 = build(:apple_credential, podcast_id: c1.podcast_id)
      refute c2.valid?
    end


    it 'is unique to an account uri' do
    end







    # it 'validates unique slugs' do
    #   assert feed2.valid?
    #   assert feed3.valid?

    #   feed3.slug = 'adfree'
    #   refute feed3.valid?

    #   feed3.slug = 'adfree2'
    #   assert feed3.valid?
    # end

    # it 'only allows 1 default feed per podcast' do
    #   assert feed1.valid?
    #   assert feed2.valid?

    #   feed2.slug = nil
    #   assert feed2.default?
    #   refute feed2.valid?

    #   feed2.podcast_id = 999999
    #   assert feed2.default?
    #   assert feed2.valid?
    # end
  end
end


# 1::::
# it 'is unique to a podcast' do
#   # c1 = create(:apple_credential, podcast: 'podcast_id')
#   # c2 = build(:apple_credential, podcast: 'podcast_id', podcast: c1.podcast)
#   # assert e1.valid?
#   # refute e2.valid?
#   end

#   # e1 = create(:episode, original_guid: 'original')
#   # e2 = build(:episode, original_guid: 'original', podcast: e1.podcast)
#   # assert e1.valid?
#   # refute e2.valid?

# //////
# c1 = build(:apple_key_id, podcast: p, podcast_id: 'foo')
# c2 = build(:apple_key_id, podcast_id: c1.podcast_id)
# assert c1.valid?
# refute c2.valid?
