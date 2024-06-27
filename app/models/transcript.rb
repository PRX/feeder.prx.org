class Transcript < ApplicationRecord
  acts_as_paranoid

  belongs_to :episode
end
