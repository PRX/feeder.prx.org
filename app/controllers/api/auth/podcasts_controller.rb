# encoding: utf-8

class Api::Auth::PodcastsController < Api::PodcastsController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::PodcastRepresenter
  filter_resources_by :prx_account_uri

  def visibile?
    visible = false
    if !show_resource
      respond_with_error(HalApi::Errors::NotFound.new)
    elsif show_resource.deleted?
      respond_with_error(ResourceGone.new)
    else
      visible = true
    end
    visible
  end
end
