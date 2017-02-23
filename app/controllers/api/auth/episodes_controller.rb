# encoding: utf-8

class Api::Auth::EpisodesController < Api::BaseController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::EpisodeRepresenter
  filter_resources_by :podcast_id
  find_method :find_by_guid

  def show
    return respond_with_error(HalApi::Errors::NotFound.new) if !show_resource
    return respond_with_error(ResourceGone.new) if show_resource.deleted?
    super
  end

  def scoped(relation)
    relation.with_deleted
  end
end
