class SubscribeLinks::Apple < SubscribeLink

  def url
    "https://podcasts.apple.com/podcast/id#{external_id}"
  end
end
