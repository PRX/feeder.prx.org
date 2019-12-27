class Api::FeedsController < Api::BaseController
  api_versions :v1
  represent_with Api::FeedRepresenter
  filter_resources_by :podcast_id
end
