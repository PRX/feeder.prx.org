class Api::PodcastsController < Api::BaseController
  api_versions :v1
  represent_with Api::PodcastRepresenter

  def scoped(relation)
    relation.published
  end
end
