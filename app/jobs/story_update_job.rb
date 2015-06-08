require 'announce'
require 'prx_access'

class StoryUpdateJob < ActiveJob::Base
  include Announce::Subscriber
  include PrxAccess

  queue_as :feeder_default

  subscribe_to :story, [:create, :update, :delete, :publish, :unpublish]

  attr_accessor :episode, :podcast, :story

  def receive_story_update(data)
    load_resources(data)
    episode ? episode.touch : create_episode
    publish_feed
  end

  alias receive_story_create receive_story_update
  alias receive_story_publish receive_story_update

  def receive_story_delete(data)
    load_resources(data)
    episode.try(:destroy)
    publish_feed
  end

  alias receive_story_unpublish receive_story_delete

  def publish_feed
    return unless podcast
    DateUpdater.both_dates(podcast)
    PublishFeedJob.perform_later(podcast)
  end

  def load_resources(data)
    @body = data.is_a?(String) ? JSON.parse(data) : data
    @story = story_resource(@body)
    @episode = Episode.with_deleted.where(prx_id: @story.attributes.id).first if @story
    @podcast = @episode.podcast if @episode
  end

  def story_resource(body)
    href = body['_links']['self']['href']
    resource = api
    link = HyperResource::Link.new(resource, href: href)
    HyperResource.new_from(body: body, resource: resource, link: link)
  end

  def create_episode
    return unless story && story.try(:series)
    if @podcast = Podcast.where(prx_id: series_id_for(story)).first
      @episode = Episode.create!(podcast: @podcast, prx_id: story.attributes.id)
    end
  end

  def series_id_for(story)
    story.series.href.split('/').last.to_i
  end
end
