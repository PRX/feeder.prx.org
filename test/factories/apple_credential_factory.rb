FactoryBot.define do
  factory :apple_credential, class: Apple::Credential do
    apple_key_id { 'some_key_id' }
    apple_key_pem_b64 { Base64.encode64(test_file('/fixtures/apple_podcasts_connect_keyfile.pem')) }
    apple_provider_id { SecureRandom.uuid }
  end
end
