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
    xml.description { xml.cdata!(@podcast.description || '') } unless @podcast.description.blank?
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

    rel = full_contact('owner', @podcast) ? 'owner' : 'author'
    xml.itunes :owner do
      xml.itunes :email, @podcast.send("#{rel}_email")
      xml.itunes :name, @podcast.send("#{rel}_name") if @podcast.send("#{rel}_name")
    end

    xml.itunes :subtitle, @podcast.subtitle unless @podcast.subtitle.blank?
    xml.itunes(:summary) { xml.cdata!(itunes_summary(@podcast)) } if show_itunes_summary?(@podcast)
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
        xml.link ep.url || ep.media_url
        xml.description { xml.cdata!(ep.description || '') }
        xml.enclosure(url: ep.media_url, type: ep.content_type, length: ep.file_size) if ep.media?

        xml.itunes :subtitle, ep.subtitle unless ep.subtitle.blank?
        xml.itunes :explicit, ep.explicit unless ep.explicit.blank?
        xml.itunes :duration, ep.duration.to_i.to_time_summary if ep.media?

        if @podcast.display_full_episodes_count.to_i <= 0 || index < @podcast.display_full_episodes_count.to_i

          has_au_email = first_nonblank('author_email', [ep, @podcast])
          xml.author(full_contact('author', has_au_email)) if full_contact('author', has_au_email)

          Array(ep.categories).each { |c| xml.category { xml.cdata!(c || '') } }

          has_author = first_nonblank('author_name', [ep, @podcast])
          xml.itunes :author, has_author.author_name if has_author && has_author.author_name

          xml.itunes(:summary) { xml.cdata!(itunes_summary(ep)) } if show_itunes_summary?(ep)

          if ep.image
            xml.itunes :image, href: ep.image.url
          elsif @podcast.itunes_image
            xml.itunes :image, href: @podcast.itunes_image.url
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
