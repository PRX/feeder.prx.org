class EpisodesController < ApplicationController
  include HalApi::Controller
  represent_with EpisodeRepresenter
  find_method :find_by_guid
end
