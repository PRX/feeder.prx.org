xml.instruct! :xml, version: '1.0'
xml.rss 'xmlns:atom' => 'http://www.w3.org/2005/Atom',
        'xmlns:itunes' => 'http://www.itunes.com/dtds/podcast-1.0.dtd',
        'xmlns:media' => 'http://search.yahoo.com/mrss/',
        'xmlns:sy' => 'http://purl.org/rss/1.0/modules/syndication/',
        'xmlns:content' => 'http://purl.org/rss/1.0/modules/content/',
        'version' => '2.0' do
  xml.channel do
    xml.title @podcast.title
    xml.link @podcast.link
    xml.pubDate @podcast.pub_date.utc.rfc2822
    xml.lastBuildDate @podcast.last_build_date.utc.rfc2822
    xml.ttl 60
    xml.language @podcast.language || 'en-us'
    xml.copyright @podcast.copyright unless @podcast.copyright.blank?
    xml.webMaster @podcast.web_master unless @podcast.web_master.blank?
    xml.description @podcast.description unless @podcast.description.blank?
    xml.managingEditor @podcast.managing_editor unless @podcast.managing_editor.blank?

    Array(@podcast.categories).each { |cat| xml.category(cat) }

    xml.generator @podcast.generator
    xml.docs 'http://blogs.law.harvard.edu/tech/rss'

    xml.image do
      xml.url @podcast.feed_image.url
      xml.title @podcast.title
      xml.link @podcast.link
      xml.width @podcast.feed_image.width
      xml.height @podcast.feed_image.height
      xml.description @podcast.feed_image.description unless @podcast.feed_image.description.blank?
    end if @podcast.feed_image

    xml.atom :link, href: (@podcast.url || @podcast.published_url), rel: 'self', type: 'application/rss+xml'

    unless @podcast.new_feed_url.blank?
      xml.itunes :'new-feed-url', @podcast.new_feed_url
    end

    xml.itunes :author, @podcast.author_name unless @podcast.author_name.blank?

    @podcast.itunes_categories[0, 3].each do |cat|
      if cat.subcategories.blank?
        xml.itunes :category, text: cat.name
      else
        xml.itunes :category, text: cat.name do
          cat.subcategories.each { |subcat| xml.itunes :category, text: subcat }
        end
      end
    end

    xml.itunes :image, href: @podcast.itunes_image.url if @podcast.itunes_image
    xml.itunes :explicit, @podcast.explicit

    unless @podcast.owner_name.blank? && @podcast.owner_email.blank?
      xml.itunes :owner do
        xml.itunes :email, @podcast.owner_email
        xml.itunes :name, @podcast.owner_name
      end
    end

    xml.itunes :subtitle, @podcast.subtitle unless @podcast.subtitle.blank?
    xml.itunes(:summary) { xml.cdata!(@podcast.summary) } unless @podcast.summary.blank?
    xml.itunes :keywords, @podcast.keywords.join(',') unless @podcast.keywords.blank?

    xml.media :copyright, @podcast.copyright unless @podcast.copyright.blank?
    xml.media :thumbnail, url: @podcast.feed_image.url if @podcast.feed_image
    xml.media :keywords, @podcast.keywords.join(',') unless @podcast.keywords.blank?

    cat = @podcast.itunes_categories.first.try(:name)
    xml.media :category, cat, scheme: 'http://www.itunes.com/dtds/podcast-1.0.dtd' unless cat.blank?

    xml.sy :updatePeriod, @podcast.update_period if @podcast.update_period
    xml.sy :updateFrequency, @podcast.update_frequency if @podcast.update_frequency
    xml.sy :updateBase, @podcast.update_base if @podcast.update_base

    @episodes.each_with_index do |ep, index|
      xml.item do
        xml.guid(ep.item_guid, isPermaLink: !!ep.is_perma_link)
        xml.title(ep.title)
        xml.pubDate ep.published_at.utc.rfc2822
        xml.link ep.url
        xml.description { xml.cdata!(ep.description || '') }
        xml.enclosure(url: ep.media_url, type: ep.content_type, length: ep.file_size) if ep.media?

        xml.itunes :subtitle, ep.subtitle unless ep.subtitle.blank?
        xml.itunes :explicit, ep.explicit unless ep.explicit.blank?
        xml.itunes :duration, ep.duration.to_i.to_time_summary if ep.media?

        if @podcast.display_full_episodes_count.to_i <= 0 || index < @podcast.display_full_episodes_count.to_i
          unless ep.author_email.blank? && ep.author_name.blank?
            xml.author "#{ep.author_email} (#{ep.author_name})"
          end

          Array(ep.categories).each { |c| xml.category { xml.cdata!(c || '') } }

          if ep.author_name || @podcast.author_name
            xml.itunes :author, (ep.author_name || @podcast.author_name)
          end

          xml.itunes(:summary) { xml.cdata!(ep.summary) } unless ep.summary.blank?

          if ep.image_url || @podcast.itunes_image
            xml.itunes :image, href: (ep.image_url || @podcast.itunes_image.url)
          end

          xml.itunes :keywords, ep.keywords.join(',') unless ep.keywords.blank?
          xml.itunes(:isClosedCaptioned, 'Yes') if ep.is_closed_captioned

          xml.media(:content,
            fileSize: ep.file_size,
            type: ep.content_type,
            url: ep.media_url) if ep.media?

          xml.content(:encoded) { xml.cdata!(ep.content) } unless ep.content.blank?
        end
      end
    end
  end
end
