class FeedImage < BaseModel
  belongs_to :podcast
  include ImageFile
end
