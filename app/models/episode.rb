class Episode < ActiveRecord::Base

  serialize :overrides, JSON

  belongs_to :podcast

  validates :podcast, presence: true

  acts_as_paranoid
end
