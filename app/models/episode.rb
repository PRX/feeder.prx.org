class Episode < ActiveRecord::Base
  belongs_to :podcast
  has_one :image, as: :imageable

  validates :title, presence: true
  validates :podcast, presence: true
  validates :description, presence: true
  validates :audio_file, presence: true
  validates :author_name, presence: true
  validates :author_email, presence: true
  validates :duration, presence: true
end
