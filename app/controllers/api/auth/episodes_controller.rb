# encoding: utf-8

class Api::Auth::EpisodesController < Api::EpisodesController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::EpisodeRepresenter
  filter_resources_by :podcast_id
  find_method :find_by_guid

  def visible?
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
