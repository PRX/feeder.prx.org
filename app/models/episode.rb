class Episode < ActiveRecord::Base
  belongs_to :podcast

  validates :podcast, presence: true

  acts_as_paranoid
end
