require 'test_helper'
require 'prx_access'

describe Podcast do

  include PRXAccess

  let(:podcast) { create(:podcast) }

  it 'has episodes' do
    assert_respond_to podcast, :episodes
  end

  it 'has a default enclosure template' do
    podcast = Podcast.new.tap {|p| p.valid? }
    assert_match(/^http/, podcast.enclosure_template_default)
    assert_equal podcast.enclosure_template, podcast.enclosure_template_default
  end

  it 'has iTunes categories' do
    assert_respond_to podcast, :itunes_categories
  end

  it 'is episodic or serial' do
    assert_match(/episodic/, podcast.itunes_type)
    podcast.update_attributes(serial_order: true)
    assert_match(/serial/, podcast.itunes_type)
  end

  it 'updates last build date after update' do
    Timecop.freeze
    podcast.update_attributes(managing_editor: 'Brian Fernandez')

    assert_equal podcast.last_build_date, Time.now

    Timecop.return
  end

  it 'wont nil out podcast published_at' do
    ep = podcast.episodes.create(published_at: 1.week.ago)
    pub_at = podcast.reload.published_at
    refute_nil podcast.published_at

    ep.update_attributes(published_at: 1.week.from_now)
    podcast.reload
    refute_nil podcast.published_at
    refute_equal podcast.published_at, ep.published_at
    refute_equal podcast.published_at, pub_at

    ep.destroy
    refute_nil podcast.reload.published_at
  end

  it 'sets the itunes block to false by default' do
    refute podcast.itunes_block
    podcast.update_attribute(:itunes_block, true)
    assert podcast.itunes_block
  end

  describe 'publishing' do

    it 'creates a publish job on publish' do
      podcast.stub(:create_publish_job, "published!") do
        assert_equal podcast.publish!, 'published!'
      end
    end

    it 'wont create a publish job when podcast is locked' do
      podcast.stub(:create_publish_job, 'published!') do
        podcast.locked = true
        refute_equal podcast.publish!, 'published!'
      end
    end
  end

  describe 'episode limit' do
    let(:episodes) { create_list(:episode, 10, podcast: podcast).reverse }

    it 'returns only limited number of episodes' do
      assert_equal episodes.count, podcast.episodes.count
      assert_equal podcast.feed_episodes.count, 10
      podcast.display_episodes_count = 5
      assert_equal podcast.feed_episodes.count, 5
    end
  end
end
