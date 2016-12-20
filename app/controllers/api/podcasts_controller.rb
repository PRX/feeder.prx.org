class Api::PodcastsController < Api::BaseController
  api_versions :v1
  represent_with Api::PodcastRepresenter
  after_action :publish, only: [:create, :update, :destroy]

  private

  def publish
    resource.publish! if resource
  end

  def scoped(relation)
    relation.published
  end
end
