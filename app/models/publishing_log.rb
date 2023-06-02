class PublishingLog < ApplicationRecord
  has_one :publishing_attempt
  belongs_to :podcast
end
