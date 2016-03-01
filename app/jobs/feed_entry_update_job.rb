require 'prx_access'

class FeedEntryUpdateJob < ActiveJob::Base
  include Announce::Subscriber
  include PRXAccess

  queue_as :feeder_default

  subscribe_to :feed_entry, [:create, :update, :delete]

  attr_accessor :body, :feed, :episode, :podcast, :entry

  def receive_feed_entry_update(data)
    load_resources(data)
    podcast ? update_podcast : create_podcast
    episode ? update_episode : create_episode
    podcast.try(:publish!)
    episode
  end
  alias receive_feed_entry_create receive_feed_entry_update

  def create_podcast
    return unless feed
    self.podcast = Podcast.create_from_feed!(feed)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => ex
    self.podcast = Podcast.find_by(source_url: feed.feed_url)
    raise ex unless podcast
    update_podcast
  end

  def update_podcast
    podcast.update_from_feed(feed)
    podcast.save!
  end

  def update_episode
    episode.restore if episode.deleted?
    episode.update_from_entry(entry)
    episode.copy_media
  end

  def create_episode
    self.episode = Episode.create_from_entry!(podcast, entry)
    episode.copy_media
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => ex
    self.episode = podcast.episodes.find_by(original_guid: entry.guid, podcast_id: podcast.id) if podcast
    raise ex unless episode
    update_episode
  end

  def receive_feed_entry_delete(data)
    load_resources(data)
    episode.destroy!
    podcast.try(:publish!)
  end

  def load_resources(data)
    self.body = data.is_a?(String) ? JSON.parse(data) : data
    self.entry = api_resource(body, crier_root)
    self.feed = entry.objects['prx:feed']

    self.podcast = Podcast.find_by(source_url: feed.feed_url)
    self.episode = podcast.episodes.with_deleted.find_by(original_guid: entry.guid, podcast_id: podcast.id) if podcast
  end
end
