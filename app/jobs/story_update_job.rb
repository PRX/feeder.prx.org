require 'prx_access'

class StoryUpdateJob < ApplicationJob
  # include Announce::Subscriber
  include PrxAccess

  queue_as :feeder_default

  # subscribe_to :story, [:create, :update, :delete, :publish, :unpublish]

  attr_accessor :body

  def receive_story_update(data)
    parse_message(data)

    # don't allow incomplete stories to alter a published episode
    return if episode.try(:published?) && action == 'update' && story.status != 'complete'

    episode ? update_episode : create_episode
    episode.try(:copy_media)
    podcast.try(:copy_media)
    podcast.try(:publish!)
  end

  alias receive_story_create receive_story_update
  alias receive_story_publish receive_story_update
  alias receive_story_unpublish receive_story_update

  def receive_story_delete(data)
    parse_message(data)

    # don't delete unless it is really deleted - should return 404/exception
    return unless story_deleted?

    self.story = api_resource(body.with_indifferent_access)

    episode.try(:destroy)
    podcast.try(:publish!)
  end

  def story_deleted?
    story_deleted = false
    begin
      get_story(body)
    rescue HyperResource::ClientError
      story_deleted = true
    end
    story_deleted
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
    return unless story&.series

    self.episode = EpisodeStoryHandler.create_from_story!(story)
    self.podcast = episode.podcast if episode
  end

  def parse_message(data)
    self.body = data.is_a?(String) ? JSON.parse(data) : data
  end

  def episode
    @episode ||= Episode.by_prx_story(story)
  end

  def podcast
    @podcast ||= episode.try(:podcast)
  end

  def story
    @story ||= get_story(body)
  end

  def get_story(story_msg)
    story = api_resource(story_msg.with_indifferent_access)
    story_url = story_auth_url(story.href)
    account_url = story.account.href
    api(account: account_url).tap { |a| a.href = story_url }.get
  end

  def story_auth_url(url)
    result = url
    if result && !result.include?('authorization')
      result = result.gsub('/stories/', '/authorization/stories/')
    end
    result
  end
end
