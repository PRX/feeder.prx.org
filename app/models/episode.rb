class Episode < ActiveRecord::Base
  belongs_to :podcast, touch: true
  has_one :image, as: :imageable

  scope :only_deleted, -> { unscoped.where("deleted_at is not null") }
  scope :with_deleted, -> { unscoped. all }
  default_scope { where("deleted_at is null") }

  def destroy
    update(deleted_at: Time.now)
  end

  def destroy!
    delete
  end

  validates :podcast, presence: true
end
