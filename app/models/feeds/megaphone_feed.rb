class Feeds::MegaphoneFeed < Feed
  has_one :megaphone_config, class_name: "::Megaphone::Config", inverse_of: :feed

  def self.model_name
    Feed.model_name
  end
end
