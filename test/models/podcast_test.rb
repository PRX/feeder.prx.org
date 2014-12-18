require 'test_helper'

describe Podcast do
  let(:podcast) { create(:podcast, :with_images) }

  it 'has episodes' do
    podcast.must_respond_to(:episodes)
  end

  it 'has an iTunes image' do
    podcast.itunes_image.wont_be(:nil?)
  end

  it 'has a channel image' do
    podcast.channel_image.wont_be(:nil?)
  end

  it 'has iTunes categories' do
    podcast.must_respond_to(:itunes_categories)
  end

  it 'must have a copyright' do
    podcast.copyright = '2014'
    podcast.wont_be :valid?

    podcast.copyright = "Copyright © 2014 #{podcast.title}. All rights reserved."
    podcast.must_be :valid?
  end
end
