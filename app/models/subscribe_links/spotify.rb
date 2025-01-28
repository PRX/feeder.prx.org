class SubscribeLinks::Spotify < SubscribeLink

  def url
    "https://open.spotify.com/#{external_id}"
  end
end
