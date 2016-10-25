require 'prx_access'

class StoryUpdateJob < ActiveJob::Base
  include Announce::Subscriber
  include PRXAccess

  queue_as :feeder_default

  subscribe_to :story, [:create, :update, :delete, :publish, :unpublish]

  attr_accessor :body, :episode, :podcast, :story

  def perform(*args)
    ActiveRecord::Base.connection_pool.with_connection do
      super
    end
  end

  def receive_story_update(data)
    load_resources(data)
    episode ? update_episode : create_episode
    episode.copy_media
    episode.podcast.publish!
  end

  alias receive_story_create receive_story_update
  alias receive_story_publish receive_story_update

  def receive_story_delete(data)
    load_resources(data)
    episode.try(:destroy)
    podcast.try(:publish!)
  end

  alias receive_story_unpublish receive_story_delete

  def load_resources(data)
    self.body = data.is_a?(String) ? JSON.parse(data) : data
    self.story = api_resource(body.with_indifferent_access)
    self.episode = Episode.by_prx_story(story)
    self.podcast = episode.podcast if episode
  end

  def update_episode
    # check the updated_at value in the message versus the db
    # if it is not more recent, do nothing
    # if it is, then retrieve the latest story from api
    #  and check the updated_at again
    # if it is truly not update,
    #  then update it with the latest from the API
    episode.restore if episode.deleted?
    self.episode = EpisodeStoryHandler.update_from_story!(episode, story)
  end

  def create_episode
    return unless story && story.try(:series)
    self.episode = EpisodeStoryHandler.create_from_story!(story)
  end
end
