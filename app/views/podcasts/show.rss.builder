xml.instruct! :xml, version: "1.0"
xml.rss "xmlns:atom" => "http://www.w3.org/2005/Atom",
  "xmlns:itunes" => "http://www.itunes.com/dtds/podcast-1.0.dtd",
  "xmlns:media" => "http://search.yahoo.com/mrss/",
  "xmlns:sy" => "http://purl.org/rss/1.0/modules/syndication/",
  "xmlns:content" => "http://purl.org/rss/1.0/modules/content/",
  "xmlns:podcast" => "https://podcastindex.org/namespace/1.0",
  "version" => "2.0" do
  xml.channel do
    xml.title @feed.title || @podcast.title
    xml.link @podcast.link
    xml.pubDate @podcast.pub_date.utc.rfc2822 if @podcast.pub_date.present?
    xml.lastBuildDate @podcast.last_build_date.utc.rfc2822
    xml.ttl 60
    xml.language @podcast.language || "en-us"
    xml.copyright @podcast.copyright unless @podcast.copyright.blank?
    xml.webMaster @podcast.web_master unless @podcast.web_master.blank?

    if @feed.description.present?
      xml.description { xml.cdata!(@feed.description) }
    elsif @podcast.description.present?
      xml.description { xml.cdata!(@podcast.description) }
    end

    xml.managingEditor @podcast.managing_editor unless @podcast.managing_editor.blank?

    Array(@podcast.categories).each { |cat| xml.category(cat) }

    xml.generator @podcast.generator
    xml.docs "http://blogs.law.harvard.edu/tech/rss"

    if @feed_image
      xml.image do
        xml.url @feed_image.url
        xml.title @feed.title || @podcast.title
        xml.link @podcast.link
        xml.width @feed_image.width
        xml.height @feed_image.height
        xml.description @feed.subtitle || @podcast.subtitle
      end
    end

    xml.atom :link, href: @feed.public_url, rel: "self", type: "application/rss+xml"

    unless @feed.new_feed_url.blank?
      xml.itunes :"new-feed-url", @feed.new_feed_url
    end

    xml.itunes :block, "Yes" if @podcast.itunes_block || @feed.try(:private)

    xml.itunes :author, @podcast.author_name unless @podcast.author_name.blank?
    xml.itunes :type, @podcast.itunes_type unless @podcast.itunes_type.blank?

    @itunes_categories[0, 3].each do |cat|
      if cat.subcategories.blank?
        xml.itunes :category, text: cat.name
      else
        xml.itunes :category, text: cat.name do
          cat.subcategories.each { |subcat| xml.itunes :category, text: subcat }
        end
      end
    end

    xml.itunes :image, href: @itunes_image.url if @itunes_image
    xml.itunes :explicit, @podcast.explicit

    rel = full_contact("owner", @podcast) ? "owner" : "author"
    xml.itunes :owner do
      xml.itunes :email, @podcast.send("#{rel}_email")
      xml.itunes :name, @podcast.send("#{rel}_name") if @podcast.send("#{rel}_name")
    end

    if @feed.subtitle.present?
      xml.itunes :subtitle, @feed.subtitle
    elsif @podcast.subtitle.present?
      xml.itunes :subtitle, @podcast.subtitle
    end

    if show_itunes_summary?(@feed)
      xml.itunes(:summary) { xml.cdata!(itunes_summary(@feed)) }
    elsif show_itunes_summary?(@podcast)
      xml.itunes(:summary) { xml.cdata!(itunes_summary(@podcast)) }
    end

    # xml.itunes :keywords, @podcast.keywords.join(",") unless @podcast.keywords.blank?

    xml.media :copyright, @podcast.copyright unless @podcast.copyright.blank?
    xml.media :thumbnail, url: @feed_image.url if @feed_image
    # xml.media :keywords, @podcast.keywords.join(",") unless @podcast.keywords.blank?

    cat = @itunes_categories.first.try(:name)
    xml.media :category, cat, scheme: "http://www.itunes.com/dtds/podcast-1.0.dtd" unless cat.blank?

    xml.sy :updatePeriod, @podcast.update_period if @podcast.update_period
    xml.sy :updateFrequency, @podcast.update_frequency if @podcast.update_frequency
    xml.sy :updateBase, @podcast.update_base if @podcast.update_base

    if @podcast.payment_pointer.present? && @feed.include_podcast_value
      xml.podcast :value, "type" => "webmonetization", "method" => "ILP" do
        xml.podcast :valueRecipient,
          "name" => @podcast.owner_name || @podcast.author_name,
          "type" => "paymentpointer",
          "address" => @podcast.payment_pointer,
          "split" => "100"
      end
    end

    if @podcast.donation_url.present? && @feed.include_donation_url
      xml.podcast :funding, "Support the Show!", "url" => @podcast.donation_url
    end

    @episodes.each_with_index do |ep, index|
      xml.item do
        xml.guid(ep.item_guid, isPermaLink: !!ep.is_perma_link)
        xml.title(ep.title)
        xml.pubDate ep.published_at.utc.rfc2822
        xml.link ep.url || ep.enclosure_url(@feed)
        xml.description { xml.cdata!(ep.description_with_default) }
        # TODO: may not reflect the content_type/file_size of replaced media
        xml.enclosure(url: ep.enclosure_url(@feed), type: ep.media_content_type(@feed), length: ep.media_file_size) if ep.media?

        xml.itunes :title, ep.clean_title unless ep.clean_title.blank?
        xml.itunes :subtitle, ep.subtitle unless ep.subtitle.blank?
        # NOTE: you'll only get a tag if this was explicitly set (pun intended)
        xml.itunes :explicit, ep.explicit unless ep.explicit.blank?
        xml.itunes :episodeType, ep.itunes_type unless ep.itunes_type.blank?
        xml.itunes :season, ep.season if ep.season?
        xml.itunes :episode, ep.number if ep.number?
        # TODO: may not reflect the duration of replaced media
        xml.itunes :duration, ep.media_duration.to_i.to_time_summary if ep.media?
        xml.itunes :block, "Yes" if ep.itunes_block

        @podcast.restrictions.try(:each) do |r|
          xml.media :restriction, r["values"].join(" "), type: r["type"], relationship: r["relationship"]
        end

        if @feed.display_full_episodes_count.to_i <= 0 || index < @feed.display_full_episodes_count.to_i

          has_au_email = first_nonblank("author_email", [ep, @podcast])
          xml.author(full_contact("author", has_au_email)) if full_contact("author", has_au_email)

          Array(ep.categories).each { |c| xml.category { xml.cdata!(c || "") } }

          has_author = first_nonblank("author_name", [ep, @podcast])
          xml.itunes :author, has_author.author_name if has_author&.author_name

          xml.itunes(:summary) { xml.cdata!(itunes_summary(ep)) } if show_itunes_summary?(ep)

          if ep.ready_image
            xml.itunes :image, href: ep.ready_image.url
          elsif @itunes_image
            xml.itunes :image, href: @itunes_image.url
          end

          # xml.itunes :keywords, ep.keywords.join(",") unless ep.keywords.blank?
          xml.itunes(:isClosedCaptioned, "Yes") if ep.is_closed_captioned

          if ep.media?
            # TODO: may not reflect the file_size/content_type/ of replaced media
            xml.media(:content,
              fileSize: ep.media_file_size,
              type: ep.media_content_type(@feed),
              url: ep.enclosure_url(@feed))
          end

          xml.content(:encoded) { xml.cdata!(ep.content) } unless ep.content.blank?
        end
      end
    end
  end
end
