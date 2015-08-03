xml.instruct! :xml, version: '1.0'
xml.rss 'xmlns:atom' => 'http://www.w3.org/2005/Atom',
        'xmlns:itunes' => 'http://www.itunes.com/dtds/podcast-1.0.dtd',
        'xmlns:media' => 'http://search.yahoo.com/mrss/',
        'xmlns:sy' => 'http://purl.org/rss/1.0/modules/syndication/',
        'xmlns:content' => 'http://purl.org/rss/1.0/modules/content/',
        'xmlns:dc' => 'http://purl.org/dc/elements/1.1/',
        'version' => '2.0' do
  xml.channel do
    xml.title @podcast.title
    xml.link @podcast.link
    xml.description @podcast.description
    xml.language @podcast.language
    xml.copyright @podcast.copyright
    xml.managingEditor @podcast.managing_editor
    xml.webMaster @podcast.web_master
    xml.pubDate @podcast.pub_date.rfc2822
    xml.lastBuildDate @podcast.last_build_date.rfc2822
    @podcast.categories.split(',').each do |category|
      xml.category category
    end
    xml.generator @podcast.generator
    xml.docs 'http://blogs.law.harvard.edu/tech/rss'
    xml.ttl 60
    xml.image do
      xml.url @podcast.feed_image.url
      xml.title @podcast.feed_image.title
      xml.link @podcast.link
      xml.width @podcast.feed_image.width
      xml.height @podcast.feed_image.height
      xml.description @podcast.feed_image.description
    end

    xml.atom :link, href: @podcast.url, rel: 'self', type: 'application/rss+xml'

    xml.itunes :author, @podcast.author

    @podcast.itunes_categories[0,3].each do |cat|
      if cat.subcategories.nil?
        xml.itunes :category, text: cat.name
      else
        xml.itunes :category, text: cat.name do
          cat.subcategories.split(', ').each do |subcat|
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
    xml.itunes(:summary) { xml.cdata!(@podcast.summary) }
    xml.itunes :keywords, @podcast.keywords

    xml.media :copyright, @podcast.copyright
    xml.media :thumbnail, url: @podcast.feed_image.url
    xml.media :keywords, @podcast.keywords
    xml.media :category, @podcast.itunes_categories.first.try(:name), scheme: 'http://www.itunes.com/dtds/podcast-1.0.dtd'

    xml.sy :updatePeriod, @podcast.update_period
    xml.sy :updateFrequency, @podcast.update_value
    xml.sy :updateBase, @podcast.update_base if @podcast.update_base

    @episodes.each do |ep|
      xml.item do
        xml.title ep[:title]
        xml.link ep[:link]
        xml.description { xml.cdata!(ep[:description][:plain]) }
        xml.author "#{ep[:author_email]} (#{ep[:author_name]})"
        unless ep[:categories].empty?
          ep[:categories].split(', ').each { |c| xml.category c }
        end
        xml.enclosure url: ep[:audio][:url], type: ep[:audio][:type], length: ep[:audio][:size]

        xml.guid ep[:guid], isPermaLink: false
        xml.pubDate ep[:pub_date]

        xml.media :content, fileSize: ep[:audio][:size], type: ep[:audio][:type], url: ep[:audio][:url]

        xml.content(:encoded) { xml.cdata!(ep[:description][:rich]) }

        xml.dc :created, ep[:created].rfc2822
        xml.dc :modified, ep[:modified].rfc2822

        xml.itunes :author, ep[:author_name]
        xml.itunes :duration, ep[:audio][:duration].to_time_string_summary
        xml.itunes :explicit, ep[:explicit]
        xml.itunes :subtitle, ep[:subtitle]
        xml.itunes :summary, ep[:summary]
        xml.itunes :keywords, ep[:keywords]
      end
    end
  end
end
