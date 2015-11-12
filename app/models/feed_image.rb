class FeedImage < ActiveRecord::Base
  belongs_to :podcast

  include ImageFile
end
