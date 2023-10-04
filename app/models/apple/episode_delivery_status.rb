module Apple
  class EpisodeDeliveryStatus < ApplicationRecord
    belongs_to :episode, class_name: "::Episode"
  end
end
