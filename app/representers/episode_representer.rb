# encoding: utf-8
require 'hal_api/representer'

class EpisodeRepresenter < HalApi::Representer
  property :item_guid, as: :guid
  property :duration
  property :published_at, as: :published

  def self_url(episode)
    episode_path(id: episode.guid)
  end

  # return as both `audio` and `media` until dovetail updated to use `media` only
  collection :audio_files, as: :audio, decorator: MediaResourceRepresenter, class: MediaResource

  collection :media_files, as: :media, decorator: MediaResourceRepresenter, class: MediaResource
end
