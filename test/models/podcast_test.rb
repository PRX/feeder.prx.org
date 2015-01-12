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

  it 'updates last build date after update' do
    now = DateTime.parse('Jan 13, 2015')

    Time.stub(:now, now) do
      podcast.update_attributes(managing_editor: 'Brian Fernandez')
    end

    podcast.last_build_date.must_equal now
  end
end
