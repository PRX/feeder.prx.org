require 'announce'
require 'prx_access'

class StoryUpdateJob < ActiveJob::Base
  include Announce::Subscriber
  include PrxAccess

  queue_as :feeder_default

  subscribe_to :story, [:update, :delete]

  attr_accessor :episode, :podcast, :story

  def receive_story_update(data)
    load_resources(data)
    episode.try(:touch) || create_episode
    DateUpdater.both_dates(podcast) if podcast
  end

  def receive_story_delete(data)
    load_resources(data)
    episode.try(:destroy)
    DateUpdater.both_dates(podcast) if podcast
  end

  def load_resources(data)
    @body = JSON.parse(data)
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
    return unless story.try(:series)
    if @podcast = Podcast.where(prx_id: series_id_for(story)).first
      @episode = Episode.create!(podcast: @podcast, prx_id: story.attributes.id)
    end
  end

  def series_id_for(story)
    story.series.href.split('/').last.to_i
  end
end
