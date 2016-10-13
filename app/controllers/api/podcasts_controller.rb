class Api::PodcastsController < Api::BaseController
  api_versions :v1
  represent_with Api::PodcastRepresenter
end
