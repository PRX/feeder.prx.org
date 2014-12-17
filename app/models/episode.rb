class Episode < ActiveRecord::Base
  belongs_to :podcast

  validates :title, presence: true
  validates :podcast, presence: true
  validates :description, presence: true
  validates :audio_file, presence: true
  validates :author, presence: true
  validates :duration, presence: true
end
