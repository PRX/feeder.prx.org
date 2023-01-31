FactoryBot.define do
  factory :user, class: "PrxAuth::Rails::Token" do
    sub { 123 }
    aur { {account_id => scopes} }

    transient do
      account_id { "10000" }
      scopes { "admin feeder:read-private feeder:podcast-edit feeder:podcast-delete feeder:podcast-create feeder:episode feeder:episode-draft" }
    end

    skip_create

    initialize_with do
      PrxAuth::Rails::Token.new(
        Rack::PrxAuth::TokenData.new(
          attributes.with_indifferent_access
        )
      )
    end

    factory(:read_only_user) do
      scopes { "read-only feeder:read-private" }
    end
  end
end
