require 'test_helper'
require 'enclosure_url_builder'

describe EnclosureUrlBuilder do
  let(:template) { "https://#{ENV['DOVETAIL_HOST']}/{slug}/{guid}/{original_filename}" }
  let(:prefix) { 'http://www.podtrac.com/pts/redirect.mp3/media.blubrry.com/jojego/' }
  let(:podcast) { create(:podcast, enclosure_prefix: prefix, enclosure_template: template) }
  let(:episode) { create(:episode, podcast: podcast, prx_uri: "/api/v1/stories/87683") }
  let(:raw_feed) { create(:feed, podcast: podcast, overrides: { enclosure_prefix: 'http://p.co/p', enclosure_template: 'http://t.co/{slug}/{filename}' } ) }
  let(:feed) { FeedDecorator.new(raw_feed) }
  let(:builder) { EnclosureUrlBuilder.new }

  before(:each) {
    podcast.enclosure_prefix = prefix
    podcast.enclosure_template = template
  }

  it 'can make an enclosure url with template, prefix, and expansions' do
    template = 'https://test.prx.tech/{a}/{b}{c}'
    expansions = { a: 'path', b: 'file', c: '.mp3'}
    prefix = 'https://prefix.prx.tech/pre'
    url = builder.enclosure_url(template, expansions, prefix)
    url.must_equal 'https://prefix.prx.tech/pre/test.prx.tech/path/file.mp3'
  end

  it 'can make expansions for a podcast and episode' do
    expansions = builder.podcast_episode_expansions(podcast, episode)
    expansions[:original_filename].must_equal "audio.mp3"
    expansions[:original_extension].must_equal ".mp3"
    expansions[:original_basename].must_equal "audio"
    expansions[:filename].must_match /ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/
    expansions[:extension].must_equal ".mp3"
    expansions[:basename].must_match /ca047dce-9df5-4132-a04b-31d24c7c55a(\d+)/
    expansions[:slug].must_equal "jjgo"
    expansions[:guid].must_match /ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)/
    expansions[:original_scheme].must_equal "s3"
    expansions[:original_host].must_equal "prx-testing"
    expansions[:original_path].must_equal "/test/audio.mp3"
    expansions[:scheme].must_equal "https"
    expansions[:host].must_equal "f.prxu.org"
    expansions[:path].must_match /\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/
  end

  it 'can make an enclosure url for a podcast and episode with template' do
    podcast.enclosure_prefix = nil
    url = builder.podcast_episode_url(podcast, episode)
    url.must_match /https:\/\/dovetail.prxu.org\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/audio.mp3/
  end

  it 'can make an enclosure url for a podcast and episode with prefix' do
    podcast.enclosure_template = nil
    url = builder.podcast_episode_url(podcast, episode)
    url.must_match /http:\/\/www.podtrac.com\/pts\/redirect.mp3\/media.blubrry.com\/jojego\/f.prxu.org\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+)\.mp3/
  end

  it 'can make an enclosure url for a podcast and episode with template and prefix' do
    url = builder.podcast_episode_url(podcast, episode)
    url.must_match /http:\/\/www.podtrac.com\/pts\/redirect.mp3\/media.blubrry.com\/jojego\/dovetail.prxu.org\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/audio\.mp3/
  end

  it 'applies template to audio file link' do
    podcast.enclosure_prefix = nil
    podcast.enclosure_template = 'http://foo.com/r{extension}/b/n/{host}{+path}'
    url = builder.podcast_episode_url(podcast, episode)
    url.must_match /http:\/\/foo\.com\/r\.mp3\/b\/n\/f\.prxu\.org\/jjgo\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+)\.mp3/
  end

  it 'can make an enclosure url for a feed and episode' do
    url = builder.podcast_episode_url(feed, episode)
    url.must_match /http:\/\/p\.co\/p\/t\.co\/jjgo\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+)\.mp3/
  end
end
