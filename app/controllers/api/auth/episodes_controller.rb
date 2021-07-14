# encoding: utf-8

class Api::Auth::EpisodesController < Api::EpisodesController
  include ApiAuthenticated
  include ApiUpdatedSince

  api_versions :v1
  represent_with Api::Auth::EpisodeRepresenter
  filter_resources_by :podcast_id
  find_method :find_by_guid

  def list_scoped(res)
    res
  end

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

  def sorted(res)
    res.order('COALESCE(published_at, released_at) DESC NULLS LAST, id DESC')
  end

  def resources_base
    @episodes ||= super.merge(authorization.token_auth_episodes)
  end
end
