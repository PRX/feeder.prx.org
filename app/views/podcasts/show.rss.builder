xml.instruct! :xml, version: '1.0'
xml.rss 'xmlns:content'=>'http://purl.org/rss/1.0/modules/content/',
        'xmlns:itunes'=>'http://www.itunes.com/dtds/podcast-1.0.dtd',
        'xmlns:media'=>'http://search.yahoo.com/mrss/',
        'xmlns:sy'=>'http://purl.org/rss/1.0/modules/syndication/',
        'xmlns:dc'=>'http://purl.org/dc/elements/1.1/',
        'xmlns:atom'=>'http://www.w3.org/2005/Atom',
        version: '2.0' do
  xml.channel do
    xml.link @podcast.link
    xml.title @podcast.title
    xml.description @podcast.description
    xml.language @podcast.language
    xml.copyright @podcast.copyright
    xml.managingEditor @podcast.managing_editor
    xml.pubDate @podcast.pub_date.strftime('%a, %d %b %Y %H:%M:%S %Z')
    xml.lastBuildDate @podcast.last_build_date.strftime('%a, %d %b %Y %H:%M:%S %Z')
    @podcast.categories.split(',').each do |category|
      xml.category category
    end

    xml.image do
      xml.url @podcast.channel_image.url
      xml.title @podcast.channel_image.title
      xml.link @podcast.channel_image.link
      xml.width @podcast.channel_image.width
      xml.height @podcast.channel_image.height
      xml.description @podcast.channel_image.description
    end

    xml.docs 'http://blogs.law.harvard.edu/tech/rss'
    xml.atom :link, podcast_path(@podcast)
    xml.generator 'PRXCast v0.0'
    xml.ttl 60

    xml.itunes :author, @podcast.author
    xml.itunes :explicit, @podcast.explicit ? 'yes' : 'no'
    xml.itunes :owner do
      xml.itunes :email, @podcast.owner_email
      xml.itunes :name, @podcast.owner_name
    end
    xml.itunes :subtitle, @podcast.subtitle
    xml.itunes :summary, @podcast.summary

    @categories.each do |cat|
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
    xml.itunes :keywords, @podcast.keywords

    xml.sy :updatePeriod, @podcast.update_period
    xml.sy :updateBase, @podcast.update_base

    @episodes.each do |ep|
      xml.item do
        xml.title ep.title
        xml.description ep.description
        xml.link ep.link
        xml.author "#{ep.author_email} (#{ep.author_name})"
        xml.pubDate ep.pub_date
        xml.source url: podcast_path(@podcast)

        if ep.categories
          ep.categories.split(', ').each { |c| xml.category c }
        end

        xml.itunes :author, ep.author_name
        xml.itunes :subtitle, ep.subtitle
        xml.itunes :summary, ep.summary
        xml.itunes :explicit, ep.explicit ? 'yes' : 'no'
        xml.itunes :duration, ep.duration
        xml.itunes :keywords, ep.categories
        xml.itunes :image, href: ep.image.url
      end
    end
  end
end
