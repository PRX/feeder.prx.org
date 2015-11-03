class FeedImage < ActiveRecord::Base
  include ImageFile

  belongs_to :podcast
end
