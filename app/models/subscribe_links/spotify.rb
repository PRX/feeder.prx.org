class SubscribeLinks::Spotify < SubscribeLink

  def href
    "https://open.spotify.com/#{external_id}"
  end
end
