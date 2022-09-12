# frozen_string_literal: true

module Apple
  class PodcastDelivery < ActiveRecord::Base
    serialize :api_response, JSON

    belongs_to :episode, class_name: "::Episode"

    enum status: {
      awaiting_upload: "AWAITING_UPLOAD",
      completed: "COMPLETED",
      failed: "FAILED",
    }
  end
end
