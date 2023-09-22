class ReplaceBetaLinks < ActiveRecord::Migration[7.0]
  def up
    podcasts = Podcast.where("link LIKE ?", "%beta.prx.org/series%")
    podcasts.each do |podcast|
      podcast.update_column(:link, podcast.embed_player_landing_url(podcast))
    end
  end
end
