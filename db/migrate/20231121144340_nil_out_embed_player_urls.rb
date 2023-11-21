class NilOutEmbedPlayerUrls < ActiveRecord::Migration[7.0]
  def up
    Podcast.with_deleted.where("link LIKE ?", "%#{ENV["PLAY_HOST"]}%").update_all(link: nil)
    Episode.with_deleted.where("url LIKE ?", "%#{ENV["PLAY_HOST"]}%").update_all(url: nil)
  end

  def down
    Podcast.with_deleted.where(link: nil).joins(:default_feed).includes(:default_feed).find_each do |p|
      ActiveRecord::Base.logger.silence do
        p.update_column(:link, p.embed_player_landing_url(p))
      end
    end

    Episode.with_deleted.where(url: nil).joins(podcast: :default_feed).includes(podcast: :default_feed).find_each do |e|
      ActiveRecord::Base.logger.silence do
        e.update_column(:url, e.embed_player_landing_url(e.podcast, e))
      end
    end
  end
end
