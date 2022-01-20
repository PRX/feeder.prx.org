require 'test_helper'

describe Feed do
  let(:podcast) { create(:podcast) }
  let(:feed1) { podcast.default_feed }
  let(:feed2) { create(:feed, podcast: podcast, slug: 'adfree') }
  let(:feed3) { create(:feed, podcast: podcast, slug: 'other') }

  describe '.new' do
    it 'sets a default file name' do
      assert_equal Feed.new.file_name, 'feed-rss.xml'
    end
  end

  describe '.default' do
    it 'returns default feeds' do
      assert feed1.default?
      refute feed2.default?
      refute feed3.default?
      assert podcast.feeds.count == 3
      assert_equal Feed.default.pluck(:id), [feed1.id]
    end
  end

  describe '#valid?' do
    it 'validates unique slugs' do
      assert feed2.valid?
      assert feed3.valid?

      feed3.slug = 'adfree'
      refute feed3.valid?

      feed3.slug = 'adfree2'
      assert feed3.valid?
    end

    it 'only allows 1 default feed per podcast' do
      assert feed1.valid?
      assert feed2.valid?

      feed2.slug = nil
      assert feed2.default?
      refute feed2.valid?

      feed2.podcast_id = 999999
      assert feed2.default?
      assert feed2.valid?
    end

    it 'restricts slug characters' do
      ['', 'n@-ats', 'no/slash', 'nospace ', 'no.dots'].each do |s|
        feed1.slug = s
        refute feed1.valid?
      end
    end

    it 'validates unique file names' do
      assert feed1.valid?
      assert feed2.valid?

      feed2.file_name = 'feed-rss.xml'
      refute feed2.valid?

      feed2.file_name = 'feed2-rss.xml'
      assert feed2.valid?
    end

    it 'restricts file name characters' do
      ['', 'n@-ats', 'no/slash', 'nospace '].each do |s|
        feed1.file_name = s
        refute feed1.valid?
      end
    end

    it 'restricts some file names already used in S3' do
      assert feed1.valid?

      feed1.file_name = 'images'
      refute feed1.valid?

      feed1.file_name = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
      refute feed1.valid?
    end
  end
end
