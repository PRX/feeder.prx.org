# encoding: utf-8
require 'hal_api/representer'

class EpisodeRepresenter < HalApi::Representer
  property :guid
  property :audio_files, as: :audio
  property :duration
  property :published

  def self_url(episode)
    episode_path(id: episode.guid)
  end
end
