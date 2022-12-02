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
      p = create(:podcast)
      c1 = create(:apple_credential, podcast: p)
      c2 = build(:apple_credential, podcast: p)
      assert c1.valid?
      refute c2.valid?
    end

    it 'is unique to an account uri' do
      c1 = create(:apple_credential, prx_account_uri: 't')
      c2 = build(:apple_credential, prx_account_uri: 't')
      assert c1.valid?
      refute c2.valid?
    end
  end
end
