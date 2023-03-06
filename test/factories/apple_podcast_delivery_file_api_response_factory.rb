FactoryBot.define do
  factory :podcast_delivery_file_api_response, class: OpenStruct do
    transient do
      podcast_delivery_id { "podcast-delivery-id" }
      podcast_delivery_file_id { "podcast-delivery-file-id" }
      file_size { 1234 }
      file_name { "some.mp3" }
      asset_role { "PodcastSourceAudio" }
      asset_processing_state { "COMPLETED" }
      asset_processing_errors { [] }
      asset_delivery_state { "COMPLETE" }
      asset_delivery_errors { [] }
      apple_episode_id { "1234" }
    end

    skip_create

    after(:build) do |response_container, evaluator|
      response_container["json"] = {"request_metadata" => {"apple_episode_id" => evaluator.apple_episode_id, "podcast_delivery_id" => evaluator.podcast_delivery_id},
       "api_url" => "https://api.podcastsconnect.apple.com/v1/podcastDeliveryFiles/#{evaluator.podcast_delivery_file_id}",
       "api_parameters" => {},
       "api_response" =>
       {"ok" => true,
        "err" => false,
        "val" =>
         {"data" =>
           {"type" => "podcastDeliveryFiles",
            "id" => evaluator.podcast_delivery_file_id,
            "attributes" =>
             {"assetType" => "ASSET",
              "fileSize" => evaluator.file_size,
              "fileName" => evaluator.file_name,
              "sourceFileChecksum" => nil,
              "assetToken" => "[FILTERED]",
              "uploadOperations" => nil,
              "uti" => "public.json",
              "assetRole" => evaluator.asset_role,
              "assetProcessingState" => {"state" => evaluator.asset_processing_state,
                                         "errors" => evaluator.asset_processing_errors,
                                         "warnings" => []},
              "assetDeliveryState" => {"errors" => evaluator.asset_delivery_errors,
                                       "warnings" => [],
                                       "state" => evaluator.asset_delivery_state}}}}}}
      response_container
    end

    initialize_with { attributes }
  end
end
