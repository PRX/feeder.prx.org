# frozen_string_literal: true

require "hash_serializer"
require "mysql2"
require "reverse_markdown"
require "s3_access"

# Do the work to synch cms and feeder
class CmsSyncher
  include S3Access

  VIDEO_CONTENT_TYPE = "video/mpeg"

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
    series
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
    story.published_at = episode.released_at
    story.released_at = episode.published_at
    story.save!

    episode.update_attribute(:prx_uri, "/api/v1/stories/#{story.id}")

    episode.images.each do |episode_image|
      save_image(story, episode_image)
    end

    # get all the audio files regardless of version
    audio_files = story.audio_files

    # get or create a version
    version = save_audio_version(episode)

    episode.media_resources.each_with_index do |media_resource, i|
      upload_url = copy_media(episode, media_resource)
      audio = version.audio_files.create!(label: "Segment #{i + 1}", upload: upload_url)
      announce_audio(audio)
      media_resource.update_attribute(:original_url, audio_file_original_url(audio))
    end

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

  def save_audio_version(episode)
    # see what template should be used for this episode
    template = template_for_episode(episode)

    # see if there is an audio version
    version = story.audio_versions.where(audio_version_template_id: template.id).first
    return version if version

    # add the correct audio version
    story.audio_versions.create!(
      audio_version_template: template,
      label: "Podcast Audio",
      explicit: episode.explicit
    )
  end

  def template_for_episode(episode)
    if episode.content_type.starts_with?("video")
      video_template(episode)
    else
      audio_template(episode)
    end
  end

  def audio_template(episode)
    num_segments = [episode.media_resources.count, 1].max
    at = series.audio_version_templates.where(segment_count: num_segments, content_type: VIDEO_CONTENT_TYPE).first
    return at if at

    series.audio_version_templates.create!(
      label: "Podcast Audio #{num_segments} #{"segment".pluralize(num_segments)}",
      content_type: AudioFile::MP3_CONTENT_TYPE,
      segment_count: num_segments,
      promos: false,
      length_minimum: 0,
      length_maximum: 0
    )
  end

  def video_template(episode)
    vt = series.audio_version_templates.where(content_type: VIDEO_CONTENT_TYPE).first
    return vt if vt

    series.audio_version_templates.create!(
      label: "Podcast Video 1 segment",
      content_type: VIDEO_CONTENT_TYPE,
      segment_count: 1,
      promos: false,
      length_minimum: 0,
      length_maximum: 0
    )
  end

  # pass in the story and episode image
  def save_image(instance, image, purpose = nil)
    # if image is nil, and purpose is not, delete all with this purpose
    if purpose.present? && image.nil?
      instance.images.destroy_by(purpose: purpose)
      return
    end

    # if the image is not yet complete, do nothing!
    return unless image.status_complete?

    # see if the image from this file exists, if so, we're done
    return if instance.images.where(upload_path: image.url).first

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
    include PorterUtils
    self.abstract_class = true
    connects_to database: {writing: :test_cms, reading: :test_cms}

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

      if Rails.env.test?
        job.to_json
      else
        porter_start!(job)
      end
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
    has_many :stories, validate: false
    has_many :images, class_name: "SeriesImage"
    has_many :audio_version_templates
    has_many :distributions, as: :distributable, dependent: :destroy
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
            Fit: (thumb == "square") ? "cover" : "inside",
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
    belongs_to :series, validate: false, optional: true
  end

  class StoryImage < CmsImage
    self.table_name = "piece_images"
    belongs_to :story, class_name: "Cms::Story", foreign_key: "piece_id", touch: true
  end

  class AudioVersionTemplate < CmsModel
    belongs_to :series, validate: false, optional: true
    has_many :audio_versions, dependent: :nullify
    has_many :audio_file_templates, -> { order :position }, dependent: :destroy
    has_many :distribution_templates, dependent: :destroy
    has_many :distributions, through: :distribution_templates
  end

  class AudioFileTemplate < CmsModel
    belongs_to :audio_version_template
  end

  class Distribution < CmsModel
    belongs_to :distributable, polymorphic: true, validate: false, optional: true
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
    belongs_to :series, validate: false, optional: true
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :user_tags, through: :taggings
    has_many :images,
      -> { where(parent_id: nil).order(:position) },
      class_name: "StoryImage",
      foreign_key: :piece_id,
      dependent: :destroy

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
    belongs_to :story, class_name: "Cms::Story", foreign_key: "piece_id"
    belongs_to :audio_version_template
    has_many :audio_files, -> { order :position }, dependent: :nullify
  end

  class AudioFile < CmsModel
    belongs_to :audio_version
    has_one :story, through: :audio_version
  end

  class StoryDistribution < CmsModel
    belongs_to :distribution
    belongs_to :story, class_name: "Cms::Story", foreign_key: "piece_id", touch: true
    serialize :properties, HashSerializer
  end

  class EpisodeDistribution < StoryDistribution
  end
end
