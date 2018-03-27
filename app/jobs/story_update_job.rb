require 'prx_access'

class StoryUpdateJob < ApplicationJob
  include Announce::Subscriber
  include PRXAccess

  queue_as :feeder_default

  subscribe_to :story, [:create, :update, :delete, :publish, :unpublish]

  attr_accessor :body, :episode, :podcast, :story

  def receive_story_update(data)
    load_resources(data)
    # don't allow invalid episodes to do anything but unpublish or delete
    return if ['create', 'update', 'publish'].include?(action) && story.status != 'complete'

    episode ? update_episode : create_episode
    episode.try(:copy_media)
    podcast.try(:copy_media)
    podcast.try(:publish!)
  end

  alias receive_story_create receive_story_update
  alias receive_story_publish receive_story_update

  def receive_story_delete(data)
    load_resources(data)
    episode.try(:destroy)
    podcast.try(:publish!)
  end

  alias receive_story_unpublish receive_story_update

  def load_resources(data)
    self.body = data.is_a?(String) ? JSON.parse(data) : data
    self.story = get_story(body)
    self.episode = Episode.by_prx_story(story)
    self.podcast = episode.podcast if episode
  end

  def get_story(story_msg)
    story = api_resource(story_msg.with_indifferent_access)
    story_url = story_auth_url(story.href)
    account_url = story.account.href
    api(account: account_url).tap { |a| a.href = story_url }.get
  end

  def story_auth_url(url)
    result = url
    if result && !result.match(/authorization/)
      result = result.gsub('/stories/', '/authorization/stories/')
    end
    result
  end

  def update_episode
    story_updated = Time.parse(story.attributes[:updated_at]) if story.attributes[:updated_at]
    if episode.source_updated_at && story_updated && story_updated < episode.source_updated_at
      logger.info("Not updating episode: #{episode.id} as #{story_updated} < #{episode.source_updated_at}")
    else
      self.episode = EpisodeStoryHandler.update_from_story!(episode, story)
    end
  end

  def create_episode
    return unless story && story.try(:series)
    self.episode = EpisodeStoryHandler.create_from_story!(story)
    self.podcast = episode.podcast if episode
  end
end
