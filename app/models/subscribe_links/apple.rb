class SubscribeLinks::Apple < SubscribeLink

  def href
    "https://podcasts.apple.com/podcast/id#{external_id}"
  end
end
