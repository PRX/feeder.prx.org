require 'prx_access'

class FeedEntryUpdateJob < ApplicationJob
  include Announce::Subscriber
  include PRXAccess

  queue_as :feeder_default

  subscribe_to :feed_entry, [:create, :update, :delete]

  attr_accessor :body, :feed, :episode, :podcast, :entry

  def receive_feed_entry_update(data)
    load_resources(data)
    podcast ? update_podcast : create_podcast
    episode ? update_episode : create_episode
    episode.try(:copy_media)
    podcast.try(:copy_media)
    podcast.try(:publish!)
    episode
  end
  alias receive_feed_entry_create receive_feed_entry_update

  def create_podcast
    return unless feed
    self.podcast = PodcastFeedHandler.create_from_feed!(feed).tap do |p|
      if update_sent && (!p.source_updated_at || update_sent > p.source_updated_at)
        p.update_attribute(:source_updated_at, update_sent)
      end
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => ex
    self.podcast = Podcast.find_by(source_url: feed.feed_url)
    raise ex unless podcast
    update_podcast
  end

  def update_podcast
    if podcast.source_updated_at && update_sent && update_sent < podcast.source_updated_at
      logger.info("Not updating podcast: #{podcast.id} as #{update_sent} < #{podcast.source_updated_at}")
    else
      podcast.restore if podcast.deleted?
      self.podcast = PodcastFeedHandler.update_from_feed!(podcast, feed).tap do |p|
        if update_sent && (!p.source_updated_at || update_sent > p.source_updated_at)
          p.update_attribute(:source_updated_at, update_sent)
        end
      end
    end
  end

  def update_episode
    if episode.source_updated_at && update_sent && update_sent < episode.source_updated_at
      logger.info("Not updating episode: #{episode.id} as #{update_sent} < #{episode.source_updated_at}")
    else
      episode.restore if episode.deleted?
      self.episode = EpisodeEntryHandler.update_from_entry!(episode, entry).tap do |e|
        if update_sent && (!e.source_updated_at || update_sent > e.source_updated_at)
          e.update_attribute(:source_updated_at, update_sent)
        end
      end
    end
  end

  def create_episode
    self.episode = EpisodeEntryHandler.create_from_entry!(podcast, entry).tap do |e|
      if update_sent && (!e.source_updated_at || update_sent > e.source_updated_at)
        e.update_attribute(:source_updated_at, update_sent)
      end
    end
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

  def update_sent
    @_update_sent ||= Time.parse(message[:sent_at])
  end

  def load_resources(data)
    self.body = data.is_a?(String) ? JSON.parse(data) : data
    self.entry = api_resource(body.with_indifferent_access, crier_root)
    self.feed = entry.objects['prx:feed']

    self.podcast = Podcast.find_by(source_url: feed.feed_url)
    self.episode = podcast.episodes.with_deleted.find_by(original_guid: entry.guid, podcast_id: podcast.id) if podcast
  end
end
