require 'test_helper'

describe Api::PodcastRepresenter do

  let(:podcast) { create(:podcast) }
  let(:representer) { Api::PodcastRepresenter.new(podcast) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'includes basic properties' do
    json['path'].must_equal 'jjgo'
    json['prxUri'].must_match /\/api\/v1\/series\//
  end

  it 'includes itunes categories' do
    json['itunesCategories'].wont_be_nil
    json['itunesCategories'].first['name'].must_equal 'Games & Hobbies'
  end

  it 'includes owner' do
    json['owner']['name'].must_equal 'Jesse Thorn'
    json['owner']['email'].must_equal 'jesse@maximumfun.org'
  end

  it 'includes keywords' do
    json['keywords'].must_include 'laffs'
  end

  it 'includes categories' do
    json['categories'].must_include 'Humor'
  end

  it 'includes itunes image' do
    json['itunesImage']['url'].must_equal 'test/fixtures/valid_series_image.jpg'
  end

  it 'includes feed image' do
    json['feedImage']['url'].must_equal 'test/fixtures/valid_feed_image.png'
  end

  it 'includes serial v. episodic ordering' do
    json['serialOrder'].must_equal false
  end

  it 'includes itunes block' do
    json['itunesBlock'].must_equal false
  end

  it 'has links' do
    json['_links']['self']['href'].must_equal "/api/v1/podcasts/#{podcast.id}"
    json['_links']['prx:series']['href'].must_equal "https://cms.prx.org#{podcast.prx_uri}"
    json['_links']['prx:account']['href'].must_equal "https://cms.prx.org#{podcast.prx_account_uri}"
  end
end
