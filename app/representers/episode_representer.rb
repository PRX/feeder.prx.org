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

  collection :audio_files, as: :audio, decorator: MediaResourceRepresenter, class: MediaResource

  # collection :audio_files, as: :audio do
  #   property :url, as: :href
  #   property :mime_type, as: :type
  #   property :file_size, as: :size
  #   property :duration
  # end
end
