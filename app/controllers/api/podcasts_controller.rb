# encoding: utf-8

class Api::PodcastsController < Api::BaseController
  api_versions :v1
  represent_with Api::PodcastRepresenter
  filter_resources_by :prx_account_uri

  after_action :process_media, only: [:create, :update]
  after_action :publish, only: [:create, :update, :destroy]

  def show
    super if visible?
  end

  def visible?
    visible = false
    if !show_resource
      respond_with_error(HalApi::Errors::NotFound.new)
    elsif show_resource.deleted?
      respond_with_error(ResourceGone.new)
    elsif !show_resource.published?
      if PodcastPolicy.new(pundit_user, show_resource).update?
        redirect_to api_authorization_podcast_path(api_version, show_resource)
      else
        respond_with_error(HalApi::Errors::NotFound.new)
      end
    else
      visible = true
    end

    visible
  end

  private

  def included(relation)
    relation.with_deleted
  end

  def process_media
    resource.copy_media if resource
  end

  def publish
    resource.publish! if resource
  end
end
