class SubscribeLink < ApplicationRecord
  belongs_to :podcast, -> { with_deleted }, optional: true, touch: true
end
