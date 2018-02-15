require 'test_helper'
require 'prx_access'

describe Podcast do

  include PRXAccess

  let(:podcast) { create(:podcast) }

  it 'has episodes' do
    podcast.must_respond_to(:episodes)
  end

  it 'has a default enclosure template' do
    podcast = Podcast.new.tap {|p| p.valid? }
    podcast.enclosure_template_default.must_match /^http/
    podcast.enclosure_template.must_equal podcast.enclosure_template_default
  end

  it 'has iTunes categories' do
    podcast.must_respond_to(:itunes_categories)
  end

  it 'is episodic or serial' do
    podcast.itunes_type.must_match /episodic/
    podcast.update_attributes(serial_order: true)
    podcast.itunes_type.must_match /serial/
  end

  it 'updates last build date after update' do
    Timecop.freeze
    podcast.update_attributes(managing_editor: 'Brian Fernandez')

    podcast.last_build_date.must_equal Time.now

    Timecop.return
  end

  it 'wont nil out podcast published_at' do
    ep = podcast.episodes.create(published_at: 1.week.ago)
    pub_at = podcast.reload.published_at
    podcast.published_at.wont_be_nil

    ep.update_attributes(published_at: 1.week.from_now)
    podcast.reload
    podcast.published_at.wont_be_nil
    podcast.published_at.wont_equal ep.published_at
    podcast.published_at.wont_equal pub_at

    ep.destroy
    podcast.reload.published_at.wont_be_nil
  end

  describe 'publishing' do

    before(:each) { podcast.tasks.delete_all }

    it 'creates a publish task on publish' do
      Task.stub :new_fixer_sqs_client, SqsMock.new do
        podcast.tasks.count.must_equal 0
        podcast.publish!
        podcast.tasks(true).count.must_equal 1
        podcast.tasks.first.must_be :is_a?, Tasks::PublishFeedTask
      end
    end

    it 'wont create a publish task when podcast is locked' do
      podcast.tasks.count.must_equal 0
      podcast.locked = true
      podcast.publish!
      podcast.tasks(true).count.must_equal 0
    end
  end

  describe 'episode limit' do
    let(:episodes) { create_list(:episode, 10, podcast: podcast).reverse }

    it 'returns only limited number of episodes' do
      episodes.count.must_equal podcast.episodes.count
      podcast.feed_episodes.count.must_equal 10
      podcast.display_episodes_count = 5
      podcast.feed_episodes.count.must_equal 5
    end
  end
end
