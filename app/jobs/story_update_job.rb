require 'announce'
require 'prx_access'

class StoryUpdateJob < ActiveJob::Base
  include Announce::Subscriber
  include PrxAccess

  queue_as :feeder_default

  subscribe_to :story, [:create, :update, :delete, :publish, :unpublish]

  attr_accessor :body, :episode, :podcast, :story

  def receive_story_update(data)
    load_resources(data)
    episode ? update_episode : create_episode
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
    self.story = story_resource(body)
    self.episode = Episode.by_prx_story(story.links['self'].href)
    self.podcast = episode.podcast if episode
  end

  def story_resource(body)
    href = body['_links']['self']['href']
    resource = api
    link = HyperResource::Link.new(resource, href: href)
    HyperResource.new_from(body: body, resource: resource, link: link)
  end

  def update_episode
    episode.touch
    episode.copy_audio
    podcast.try(:publish!)
  end

  def create_episode
    return unless story && story.try(:series)
    series_uri = story.links['series'].href
    story_uri = story.links['self'].href
    self.podcast = Podcast.where(prx_uri: series_uri).first
    if podcast
      self.episode = Episode.create!(podcast: podcast, prx_uri: story_uri)
      episode.copy_audio
    end
  end
end
