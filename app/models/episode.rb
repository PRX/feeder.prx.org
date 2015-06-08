class Episode < ActiveRecord::Base
  belongs_to :podcast

  validates :podcast, presence: true

  acts_as_paranoid

  before_save :set_guid

  def set_guid
    return if guid
    self.guid = "prx:#{story_id}:#{SecureRandom.uuid}"
  end

  def story_id
    prx_id
  end
end
