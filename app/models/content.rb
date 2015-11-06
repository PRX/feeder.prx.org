class Content < MediaResource
  acts_as_list scope: :episode
end
