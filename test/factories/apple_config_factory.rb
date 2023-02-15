FactoryBot.define do
  factory :apple_config, class: Apple::Config do
    apple_key_id { "some_key_id" }
    apple_key_pem_b64 { Base64.encode64(test_file("/fixtures/apple_podcasts_connect_keyfile.pem")) }
    apple_provider_id { SecureRandom.uuid }

    transient do
      podcast { build(:podcast) }
    end

    # set up the private and public feeds
    before(:create) do |apple_config, evaluator|
      apple_config.public_feed ||= create(:feed, podcast: evaluator.podcast)
      apple_config.private_feed ||= create(:feed, podcast: evaluator.podcast)
    end
  end
end
