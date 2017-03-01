# encoding: utf-8

class Api::EpisodesController < Api::BaseController
  api_versions :v1
  represent_with Api::EpisodeRepresenter
  find_method :find_by_guid
  filter_resources_by :podcast_id

  after_action :process_media, only: [:create, :update]
  after_action :publish, only: [:create, :update, :destroy]

  def show
    super if visibile?
  end

  def visibile?
    visible = false
    if !show_resource
      respond_with_error(HalApi::Errors::NotFound.new)
    elsif show_resource.deleted?
      respond_with_error(ResourceGone.new)
    elsif !show_resource.published?
      if EpisodePolicy.new(pundit_user, show_resource).update?
        redirect_to api_authorization_episode_path(api_version, show_resource)
      else
        respond_with_error(HalApi::Errors::NotFound.new)
      end
    else
      visible = true
    end
    visible
  end

  def scoped(relation)
    relation.with_deleted
  end

  def process_media
    resource.copy_media if resource
  end

  def publish
    resource.podcast.publish! if resource && resource.podcast
  end
end
