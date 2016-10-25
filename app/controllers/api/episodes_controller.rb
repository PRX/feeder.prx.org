class Api::EpisodesController < Api::BaseController
  api_versions :v1
  represent_with Api::EpisodeRepresenter
  filter_resources_by :podcast_id
  find_method :find_by_guid
end
