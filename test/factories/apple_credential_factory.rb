FactoryGirl.define do
  factory :apple_credential do
    apple_provider_id 'gala apples'
    apple_key_id 'some-apple-key'
    apple_key_pem_b64 'c29tZS1hcHBsZS1rZXktcGVt'
  end
end
