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
    end

    it 'is unique to a podcast' do
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
