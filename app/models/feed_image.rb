class FeedImage < BaseModel
  belongs_to :podcast, touch: true
  include ImageFile
end
