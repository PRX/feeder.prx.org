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
    xml.copyright @podcast.copyright
    xml.webMaster @podcast.web_master
    xml.description @podcast.description
    xml.managingEditor @podcast.managing_editor
    @podcast.categories.each do |category|
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
    end

    xml.atom :link, href: (@podcast.url || @podcast.published_url), rel: 'self', type: 'application/rss+xml'

    xml.itunes :author, @podcast.author_name

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

    xml.itunes :image, href: @podcast.itunes_image.url
    xml.itunes :explicit, @podcast.explicit ? 'yes' : 'no'
    xml.itunes :owner do
      xml.itunes :email, @podcast.owner_email
      xml.itunes :name, @podcast.owner_name
    end
    xml.itunes :subtitle, @podcast.subtitle
    xml.itunes(:summary) { xml.cdata!(@podcast.summary || '') }
    xml.itunes :keywords, @podcast.keywords.join(',') if @podcast.keywords.size > 0

    xml.media :copyright, @podcast.copyright
    xml.media :thumbnail, url: @podcast.feed_image.url
    xml.media :keywords, @podcast.keywords.join(',') if @podcast.keywords.size > 0
    xml.media :category, @podcast.itunes_categories.first.try(:name), scheme: 'http://www.itunes.com/dtds/podcast-1.0.dtd'

    xml.sy :updatePeriod, @podcast.update_period if @podcast.update_period
    xml.sy :updateFrequency, @podcast.update_frequency if @podcast.update_frequency
    xml.sy :updateBase, @podcast.update_base if @podcast.update_base

    @episodes.each do |ep|
      xml.item do
        xml.guid ep[:guid], isPermaLink: !!ep[:is_perma_link]
        xml.title ep[:title]
        xml.author "#{ep[:author_email]} (#{ep[:author_name]})"
        xml.pubDate (ep[:published] || ep[:created]).utc.rfc2822
        xml.link ep[:link]
        xml.description { xml.cdata!(ep[:description] || '') }
        unless ep[:categories].empty?
          ep[:categories].each { |c| xml.category { xml.cdata!(c) } }
        end
        xml.enclosure url: ep[:audio][:url], type: ep[:audio][:type], length: ep[:audio][:size]

        xml.itunes :duration, ep[:audio][:duration].to_time_summary
        xml.itunes :author, @podcast.author_name
        xml.itunes :explicit, ep[:explicit]
        xml.itunes(:summary) { xml.cdata!(ep[:summary] || '') }
        xml.itunes :subtitle, ep[:subtitle]
        xml.itunes :image, href: (ep[:image_url] || @podcast.itunes_image.url)
        xml.itunes :keywords, ep[:keywords].join(',')
        xml.itunes(:isClosedCaptioned, ep[:is_closed_captioned]) if ep.key?(:is_closed_captioned)

        xml.media(:content, fileSize: ep[:audio][:size], type: ep[:audio][:type], url: ep[:audio][:url])
        xml.content(:encoded) { xml.cdata!(ep[:content] || '') }
        # xml.dc :created, ep[:created].utc.rfc2822
        # xml.dc :modified, ep[:modified].utc.rfc2822
      end
    end
  end
end
