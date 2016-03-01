xml.instruct! :xml, version: '1.0'
xml.rss 'xmlns:atom' => 'http://www.w3.org/2005/Atom',
        'xmlns:itunes' => 'http://www.itunes.com/dtds/podcast-1.0.dtd',
        'xmlns:media' => 'http://search.yahoo.com/mrss/',
        'xmlns:sy' => 'http://purl.org/rss/1.0/modules/syndication/',
        'xmlns:content' => 'http://purl.org/rss/1.0/modules/content/',
        # 'xmlns:dc' => 'http://purl.org/dc/elements/1.1/',
        'version' => '2.0' do
  xml.channel do
    xml.title @podcast.title
    xml.link @podcast.link
    xml.pubDate @podcast.pub_date.utc.rfc2822
    xml.lastBuildDate @podcast.last_build_date.utc.rfc2822
    xml.ttl 60
    xml.language @podcast.language || 'en-us'
    xml.copyright @podcast.copyright if @podcast.copyright
    xml.webMaster @podcast.web_master if @podcast.web_master
    xml.description @podcast.description
    xml.managingEditor @podcast.managing_editor if @podcast.managing_editor

    Array(@podcast.categories).each do |category|
      xml.category category
    end

    xml.generator @podcast.generator
    xml.docs 'http://blogs.law.harvard.edu/tech/rss'

    xml.image do
      xml.url @podcast.feed_image.url
      xml.title @podcast.title
      xml.link @podcast.link
      xml.width @podcast.feed_image.width
      xml.height @podcast.feed_image.height
      xml.description @podcast.feed_image.description if @podcast.feed_image.description
    end if @podcast.feed_image

    xml.atom :link, href: (@podcast.url || @podcast.published_url), rel: 'self', type: 'application/rss+xml'

    xml.itunes :author, @podcast.author_name if @podcast.author_name

    @podcast.itunes_categories[0,3].each do |cat|
      if cat.subcategories.nil?
        xml.itunes :category, text: cat.name
      else
        xml.itunes :category, text: cat.name do
          cat.subcategories.each do |subcat|
            xml.itunes :category, text: subcat
          end
        end
      end
    end

    xml.itunes :image, href: @podcast.itunes_image.url if @podcast.itunes_image
    xml.itunes :explicit, @podcast.explicit ? 'yes' : 'no'

    if (@podcast.owner_name || @podcast.owner_email)
      xml.itunes :owner do
        xml.itunes :email, @podcast.owner_email
        xml.itunes :name, @podcast.owner_name
      end
    end

    xml.itunes :subtitle, @podcast.subtitle if @podcast.subtitle
    xml.itunes(:summary) { xml.cdata!(@podcast.summary) } if @podcast.summary
    xml.itunes :keywords, @podcast.keywords.join(',') if !@podcast.keywords.blank?

    xml.media :copyright, @podcast.copyright if @podcast.copyright
    xml.media :thumbnail, url: @podcast.feed_image.url if @podcast.feed_image
    xml.media :keywords, @podcast.keywords.join(',') if !@podcast.keywords.blank?
    xml.media :category, @podcast.itunes_categories.first.try(:name), scheme: 'http://www.itunes.com/dtds/podcast-1.0.dtd'

    xml.sy :updatePeriod, @podcast.update_period if @podcast.update_period
    xml.sy :updateFrequency, @podcast.update_frequency if @podcast.update_frequency
    xml.sy :updateBase, @podcast.update_base if @podcast.update_base

    @episodes.each do |ep|
      xml.item do
        xml.guid ep[:guid], isPermaLink: !!ep[:is_perma_link]
        xml.title ep[:title]

        if ep[:author_email] || ep[:author_name]
          xml.author "#{ep[:author_email]} (#{ep[:author_name]})"
        end

        xml.pubDate (ep[:published] || ep[:created]).utc.rfc2822
        xml.link ep[:link]
        xml.description { xml.cdata!(ep[:description] || '') }

        unless ep[:categories].blank?
          ep[:categories].each { |c| xml.category { xml.cdata!(c) } }
        end

        if m = ep[:media]
          xml.enclosure url: m[:url], type: m[:type], length: m[:size]
        end

        xml.itunes :duration, ep[:media][:duration].to_time_summary if ep[:media]
        xml.itunes :author, @podcast.author_name if @podcast.author_name
        xml.itunes :explicit, ep[:explicit] if ep.key?(:explicit)
        xml.itunes(:summary) { xml.cdata!(ep[:summary]) } if ep[:summary]
        xml.itunes :subtitle, ep[:subtitle] if ep[:subtitle]

        if ep[:image_url] || @podcast.itunes_image
          xml.itunes :image, href: (ep[:image_url] || @podcast.itunes_image.url)
        end

        xml.itunes :keywords, ep[:keywords].join(',') if !ep[:keywords].blank?
        xml.itunes(:isClosedCaptioned, ep[:is_closed_captioned]) if ep.key?(:is_closed_captioned)

        if m = ep[:media]
          xml.media(:content, fileSize: m[:size], type: m[:type], url: m[:url])
        end

        if ep[:content]
          xml.content(:encoded) { xml.cdata!(ep[:content]) }
        end

        # xml.dc :created, ep[:created].utc.rfc2822
        # xml.dc :modified, ep[:modified].utc.rfc2822
      end
    end
  end
end
