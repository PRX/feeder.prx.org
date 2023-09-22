class ReplaceBetaLinks < ActiveRecord::Migration[7.0]
  def up
    podcasts = Podcast.where("link LIKE ?", "%#{ENV["PRX_HOST"]}/series%")
    podcasts.each do |podcast|
      podcast.update_column(:link, podcast.embed_player_landing_url(podcast))
    end

    eps = Episode.where("url LIKE ?", "%#{ENV["PRX_HOST"]}/stories%")
    eps.each do |ep|
      ep.update_column(:url, ep.embed_player_landing_url(ep.podcast, ep))
    end
  end
end
