class SubscribeLink < ApplicationRecord
  TYPE_ABBREVIATIONS = {
    "SubscribeLinks::Apple" => "apple",
    "SubscribeLinks::Spotify" => "spotify"
  }

  belongs_to :podcast, -> { with_deleted }, optional: true, touch: true

  def label
    TYPE_ABBREVIATIONS[type]
  end
end
