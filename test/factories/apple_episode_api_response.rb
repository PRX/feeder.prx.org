FactoryBot.define do
  factory :apple_episode_api_response, class: OpenStruct do
    transient do
      apple_episode_id { "1234" }
      item_guid { "item-guid" }
      ok { true }
      err { false }
      api_url { "http://the-api-url.com/v1/episodes/123" }
      apple_hosted_audio_asset_container_id { "456" }
      publishing_state { "DRAFTING" }
      apple_hosted_audio_state { "UNSPECIFIED" }
    end

    skip_create

    after(:build) do |response_container, evaluator|
      response_container["api_response"] =
        {"request_metadata" => {"apple_episode_id" => evaluator.apple_episode_id, "item_guid" => evaluator.item_guid},
         "api_url" => evaluator.api_url,
         "api_parameters" => {},
         "api_response" => {"ok" => evaluator.ok,
                            "err" => evaluator.err,
                            "val" => {"data" => {"id" => "123",
                                                 "attributes" => {
                                                   "appleHostedAudioAssetVendorId" => evaluator.apple_hosted_audio_asset_container_id,
                                                   "publishingState" => evaluator.publishing_state,
                                                   "guid" => evaluator.item_guid,
                                                   "appleHostedAudioAssetState" => evaluator.apple_hosted_audio_state
                                                 }}}}}.with_indifferent_access
      response_container
    end

    initialize_with { attributes }
  end
end
