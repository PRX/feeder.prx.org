class FeedImage < ActiveRecord::Base
  belongs_to :podcast

  validates_with FeedImageValidator
end
