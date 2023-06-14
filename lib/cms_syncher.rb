# frozen_string_literal: true

require "hash_serializer"
require "mysql2"
require "reverse_markdown"
require "s3_access"

# Do the work to synch cms and feeder
class CmsSyncher
  include S3Access

  # Create or update series
  def sync_series(podcast, user_id)
    series_id = id_from_uri(podcast.prx_uri)
    series = Cms::Series.find_by_id(series_id) || Cms::Series.new
    update_series(series, podcast, user_id)
  end

  def update_series(series, podcast, user_id)
    series.app_version = Cms::APP_VERSION
    series.creator_id = user_id
    series.account_id = podcast.account_id
    series.title = podcast.title
    series.short_description = podcast.subtitle
    series.description = html_to_markdown(podcast.description)
    series.save!

    # we only get a series id after save for a new series
    podcast.update_attribute(:prx_uri, "/api/v1/series/#{series.id}")

    save_image(series, podcast.itunes_image, Cms::PROFILE)
    save_image(series, podcast.feed_image, Cms::THUMBNAIL)
  end

  def sync_story(episode, user_id)
    story_id = id_from_uri(episode.prx_uri)
    story = Cms::Story.find_by_id(story_id) || Cms::Story.new
    update_story(story, episode, user_id)
  end

  def update_story(story, episode, user_id)
    story.creator_id = user_id
    story.app_version = Cms::APP_VERSION
    story.deleted_at = DateTime.now
    story.account_id = episode.podcast.account_id
    story.title = episode.title
    story.short_description = episode.subtitle
    story.description = episode_description(episode)
    story.tags = episode.categories
    story.published_at = episode.published_at
    story.released_at = episode.published_at
    story.save!

    episode.update_attribute(:prx_uri, "/api/v1/stories/#{story.id}")

    episode.episode_images.each do |episode_image|
      save_image(story, episode_image)
    end

    # version = story.audio_versions.create!(
    #   audio_version_template: template_for_episode(episode),
    #   label: 'Podcast Audio',
    #   explicit: episode.explicit
    # )

    # episode.media_resources.each_with_index do |media_resource, i|
    #   upload_url = copy_media(episode, media_resource)
    #   audio = version.audio_files.create!(label: "Segment #{i + 1}", upload: upload_url)
    #   announce_audio(audio)
    #   media_resource.update_attribute(:original_url, audio_file_original_url(audio))
    # end

    # # create the story distribution
    # episode_url = "#{feeder_root}/episodes/#{episode.guid}"
    # story.distributions << StoryDistributions::EpisodeDistribution.create!(
    #   distribution: distribution,
    #   story: story,
    #   guid: episode.item_guid,
    #   url: episode_url
    # )

    story
  end

  # pass in the story and episode image
  def save_image(instance, image, purpose = nil)
    # if image is nil, and purpose is not, delete all with this purpose
    if purpose.present? && image.nil?
      instance.images.destroy_by(purpose: purpose)
      return
    end

    # if the image is not yet complete, do nothing!
    return unless image.complete?

    # see if the image from this file exists, if so, we're done
    return if instance.images.first(upload_path: image.url).first

    # ok, actually create it!
    create_image(instance, image, purpose)
  end

  def create_image(instance, image, purpose)
    # ok, we need to add this image to cms
    attrs = {
      status: "complete", # assume the processing will work ;)
      upload_path: image.url,
      content_type: "image/#{image.format}",
      filename: URI.parse(image.url || "").path.split("/").last,
      size: image.size,
      height: image.height,
      width: image.width,
      aspect_ratio: image.height.to_f.positive? ? (image.width / image.height.to_f) : nil
    }

    attrs[:purpose] = purpose if purpose.present?

    instance_image = instance.images.create!(attrs)

    # copy or create files using porter from feeder bucket and file
    instance_image.porter_store_files(s3_bucket, image.destination_path)
  end

  def episode_description(episode)
    attrname = %i[content summary description subtitle title].find { |d| !episode[d].blank? }
    html_to_markdown(episode[attrname])
  end

  def html_to_markdown(str)
    return nil unless str

    ReverseMarkdown.convert(str).strip
  end

  def id_from_uri(uri)
    URI.parse(uri || "").path.split("/").last.to_i
  end
end

module Cms
  APP_VERSION = "v4"
  PROFILE = "profile"
  THUMBNAIL = "thumbnail"
  PURPOSES = [PROFILE, THUMBNAIL].freeze
  CMS_BUCKET = ENV["CMS_STORAGE_BUCKET"] || "production.mediajoint.prx.org"

  # Base model class for CMS database access
  class CmsModel < ActiveRecord::Base
    include PorterEncoder
    self.abstract_class = true

    def self.cms_db_connection
      {
        adapter: "mysql2",
        encoding: "utf8mb4",
        collation: "utf8mb4_unicode_ci",
        pool: ENV["CMS_DATABASE_POOL_SIZE"],
        username: ENV["CMS_MYSQL_USER"],
        password: ENV["CMS_MYSQL_PASSWORD"],
        host: ENV["CMS_MYSQL_HOST"],
        port: ENV["CMS_MYSQL_PORT"],
        database: ENV["CMS_MYSQL_DATABASE"],
        reconnect: true
      }
    end

    establish_connection(cms_db_connection)

    def copy_original_task
      {
        Type: "Copy",
        Mode: "AWS/S3",
        BucketName: Cms::CMS_BUCKET,
        ObjectKey: s3_object_key,
        ContentType: "REPLACE",
        Parameters: {
          ContentDisposition: "attachment; filename=\"#{filename}\""
        }
      }
    end

    def porter_store_files(source_bucket, source_key)
      job = {
        Id: SecureRandom.uuid,
        Source: {Mode: "AWS/S3", BucketName: source_bucket, ObjectKey: source_key},
        Tasks: [copy_original_task] + thumbnail_tasks
      }

      porter_publish(job)
    end

    def s3_object_key(thumb = nil)
      "public/#{self.class.name.tableize}/#{id}/#{thumbnail_name(thumb)}"
    end

    def thumbnail_name(thumb = nil)
      return filename if thumb.nil?

      ext = File.extname(filename)
      base = File.basename(filename, ext)
      "#{base}_#{thumb}#{ext}"
    end
  end

  # Series AR
  class Series < CmsModel
    has_many :stories
    has_many :series_images
  end

  class CmsImage < CmsModel
    self.abstract_class = true

    def self.version_formats
      {
        "square" => [75, 75],
        "small" => [120, 120],
        "medium" => [240, 240]
      }
    end

    def thumbnail_tasks
      self.class.version_formats.map do |(thumb, dimensions)|
        derivative = s3_object_key(thumb)
        {
          Type: "Image",
          Metadata: "PRESERVE",
          Resize: {
            Fit: (name == "square") ? "cover" : "inside",
            Height: dimensions[1],
            Position: "centre",
            Width: dimensions[0]
          },
          Destination: {
            Mode: "AWS/S3",
            BucketName: Cms::CMS_BUCKET,
            ObjectKey: derivative,
            ContentType: "REPLACE",
            Parameters: {
              ContentDisposition: "attachment; filename=\"#{File.basename(derivative)}\""
            }
          }
        }
      end
    end
  end

  class SeriesImage < CmsImage
    belongs_to :series
  end

  class StoryImage < CmsImage
    self.table_name = "piece_images"
    belongs_to :story, -> { with_deleted }, class_name: "Cms::Story", foreign_key: "piece_id", touch: true
  end

  class AudioVersionTemplate < CmsModel
    belongs_to :series
    has_many :audio_versions, dependent: :nullify
    has_many :audio_file_templates, -> { order :position }, dependent: :destroy
    has_many :distribution_templates, dependent: :destroy
    has_many :distributions, through: :distribution_templates
  end

  class AudioFileTemplate < CmsModel
    belongs_to :audio_version_template
  end

  class Distribution < CmsModel
    belongs_to :distributable, polymorphic: true
    has_many :story_distributions
    has_many :distribution_templates, dependent: :destroy, autosave: true
    has_many :audio_version_templates, through: :distribution_templates
    serialize :properties, HashSerializer
  end

  class DistributionTemplate < CmsModel
    belongs_to :distribution
    belongs_to :audio_version_template
  end

  class PodcastDistribution < Distribution
  end

  # Story AR
  class Story < CmsModel
    self.table_name = "pieces"
    belongs_to :series
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :user_tags, through: :taggings

    def tags=(ts)
      self.user_tags = (ts || []).uniq.sort.map { |t| UserTag.new(name: t.strip) }
    end
  end

  class Tagging < CmsModel
    belongs_to :user_tag, foreign_key: :tag_id
    belongs_to :taggable, polymorphic: true, touch: true
  end

  class UserTag < CmsModel
    self.table_name = "tags"
    has_many :taggings
    has_many :taggables, through: :taggings
  end

  class AudioVersion < CmsModel
    belongs_to :story, -> { with_deleted }, class_name: "Cms::Story", foreign_key: "piece_id"
    belongs_to :audio_version_template
    has_many :audio_files, -> { order :position }, dependent: :destroy
  end

  class StoryDistribution < CmsModel
    belongs_to :distribution
    belongs_to :story, -> { with_deleted }, class_name: "Cms::Story", foreign_key: "piece_id", touch: true
    serialize :properties, HashSerializer
  end

  class EpisodeDistribution < StoryDistribution
  end
end
