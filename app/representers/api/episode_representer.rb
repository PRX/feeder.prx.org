# encoding: utf-8

class Api::EpisodeRepresenter < Api::BaseRepresenter
  property :item_guid, as: :guid
  property :duration
  property :published_at, as: :published

  def self_url(episode)
    episode_path(id: episode.guid)
  end

  collection :media_files, as: :media, decorator: MediaResourceRepresenter, class: MediaResource
end
