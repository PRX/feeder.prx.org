class FeedImage < ActiveRecord::Base
  include ImageFile

  belongs_to :podcast

  validates :link, :title, presence: true
end
