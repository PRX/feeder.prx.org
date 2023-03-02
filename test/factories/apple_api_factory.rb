FactoryBot.define do
  factory :apple_api, class: Apple::Api do
    provider_id { SecureRandom.uuid }
    key { test_file("/fixtures/apple_podcasts_connect_keyfile.pem") }
    key_id { "some_key_id" }

    initialize_with { new(provider_id: provider_id, key_id: key_id, key: key) }
  end
end
