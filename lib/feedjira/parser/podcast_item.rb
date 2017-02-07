module Feedjira
  module Parser
    class PodcastItem
      include SAXMachine
      include FeedEntryUtilities

      element :title
      element :link, as: :url
      element :description, as: :description
      element :author
      elements :category, as: :categories
      element :comments
      element :enclosure, class: PodcastItemEnclosure
      element :guid, as: :entry_id
      element :guid, value: :isPermaLink, as: :is_perma_link
      element :pubDate, as: :published

      element :"itunes:author", as: :itunes_author
      element :"itunes:block", as: :itunes_block
      element :"itunes:image", value: :href, as: :itunes_image
      element :"itunes:duration", as: :itunes_duration
      element :"itunes:explicit", as: :itunes_explicit
      element :"itunes:isClosedCaptioned", as: :itunes_is_closed_captioned
      element :"itunes:order", as: :itunes_order
      element :"itunes:subtitle", as: :itunes_subtitle
      element :"itunes:summary", as: :itunes_summary
      element :"itunes:keywords", as: :itunes_keywords

      element :"feedburner:origLink", as: :feedburner_orig_link
      element :"feedburner:origEnclosureLink", as: :feedburner_orig_enclosure_link

      elements :"media:content", as: :media_contents, class: MediaContent
      elements :"media:group", as: :media_groups, class: MediaGroup

      element :"content:encoded", as: :content
      element :"wfw:commentRss", as: :comment_rss_url
      element :"slash:comments", as: :comment_count
      element :"dc:creator", as: :creator
      element :pubdate, as: :published
      element :"dc:date", as: :published
      element :"dc:Date", as: :published
      element :"dcterms:created", as: :published
      element :"dc:identifier", :as => :entry_id
      element :issued, as: :published
      element :"dcterms:modified", as: :updated
    end
  end
end
