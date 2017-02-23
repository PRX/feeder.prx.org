class Api::EpisodesController < Api::BaseController
  api_versions :v1
  represent_with Api::EpisodeRepresenter
  filter_resources_by :podcast_id
  find_method :find_by_guid

  after_action :publish, only: [:create, :update, :destroy]
  after_action :process_media, only: [:create, :update]

  def show
    return respond_with_error(HalApi::Errors::NotFound.new) if !show_resource
    return respond_with_error(ResourceGone.new) if show_resource.deleted?
    return super if show_resource.published?

    if EpisodePolicy.new(pundit_user, show_resource).update?
      redirect_to api_authorization_episode_path(api_version, show_resource)
    else
      respond_with_error(HalApi::Errors::NotFound.new)
    end
  end

  private

  def process_media
    resource.copy_media if resource
  end

  def publish
    resource.podcast.publish! if resource && resource.podcast
  end

  def scoped(relation)
    relation.with_deleted
  end
end
