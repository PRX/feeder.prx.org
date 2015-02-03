class Podcast < ActiveRecord::Base
  has_one :itunes_image, class_name: :Image, as: :imageable
  has_one :channel_image, class_name: :Image, as: :imageable

  has_many :episodes
  has_many :itunes_categories

  default_scope { where("deleted_at is null") }
  scope :only_deleted, -> { unscoped.where("deleted_at is not null") }
  scope :with_deleted, -> { unscoped.all }

  after_update do
    DateUpdater.last_build_date(self)
  end

  def destroy
    update(deleted_at: Time.now)
  end

  def destroy!
    delete
  end
end
