# encoding: utf-8
require 'hal_api/representer'

class EpisodeRepresenter < HalApi::Representer
  property :item_guid, as: :guid
  property :audio_files, as: :audio
  property :duration
  property :published_at, as: :published

  def self_url(episode)
    episode_path(id: episode.guid)
  end
end
