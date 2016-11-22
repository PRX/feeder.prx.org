# encoding: utf-8

class Api::Auth::EpisodesController < Api::EpisodesController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::EpisodeRepresenter
  find_method :find_by_guid

  def scoped(relation)
    relation
  end
end
