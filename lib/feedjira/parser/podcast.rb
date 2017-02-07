require 'feedjira'
require 'feedjira/parser/media_content'
require 'feedjira/parser/media_group'
require 'feedjira/parser/podcast_image'
require 'feedjira/parser/podcast_item_enclosure'
require 'feedjira/parser/podcast_item'

module Feedjira
  module Parser
    class Podcast
      include SAXMachine
      include FeedUtilities

      attr_accessor :feed_url

      # RSS 2.0 elements that need including
      element :title
      element :link, as: :url
      element :description
      element :language
      element :copyright
      element :managingEditor, as: :managing_editor
      element :webMaster, as: :web_master
      elements :category, as: :categories
      element :generator
      element :ttl

      element :image, class: PodcastImage

      element :pubDate, as: :pub_date_string
      element :lastBuildDate, as: :last_built_string

      element :"itunes:author", as: :itunes_author
      element :"itunes:block", as: :itunes_block
      elements :"itunes:category", as: :itunes_categories, value: :text
      element :"itunes:image", value: :href, as: :itunes_image
      element :"itunes:explicit", as: :itunes_explicit
      element :"itunes:complete", as: :itunes_complete
      element :"itunes:new_feed_url", as: :itunes_new_feed_url
      elements :"itunes:owner", as: :itunes_owners, class: ITunesRSSOwner
      element :"itunes:subtitle", as: :itunes_subtitle
      element :"itunes:summary", as: :itunes_summary
      element :"itunes:keywords", as: :itunes_keywords

      element :"sy:updatePeriod", as: :update_period
      element :"sy:updateFrequency", as: :update_frequency
      element :"feedburner:info", as: :feedburner_name, :value => :uri

      elements :link, as: :hubs, value: :href, with: {rel: "hub"}
      elements :"atom10:link", as: :hubs, value: :href, with: {rel: "hub"}

      elements :item, as: :entries, class: PodcastItem

      element :"media:copyright", as: :media_copyright
      element :"media:thumbnail", as: :media_thumbnail
      element :"media:keywords", as: :media_keywords
      elements :"media:category", as: :media_categories

      def published
        [last_modified, pub_date, last_built].compact.max
      end

      def pub_date
        parse_datetime(pub_date_string)
      end

      def last_built
        parse_datetime(last_built_string)
      end

      def parse_datetime(value)
        DateTime.parse(value).utc if value.present?
      rescue ArgumentError
        nil
      end

      def self.able_to_parse?(xml) #:nodoc:
        (/\<rss|\<rdf/ =~ xml)
      end
    end
  end
end
