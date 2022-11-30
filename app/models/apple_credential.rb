class AppleCredential < ActiveRecord::Base
  belongs_to :podcast, -> { with_deleted }

  validates_associated :podcast, if: -> { prx_account_uri.blank? }
  validates_presence_of :prx_account_uri, if: -> { podcast.blank? }
  validates_presence_of :apple_key_id
  validates_presence_of :apple_key_pem_b64
  validate :podcast_and_prx_account_uri_not_both_set

  def podcast_and_prx_account_uri_not_both_set
    if podcast.present? && prx_account_uri.present?
      errors.add(:prx_account_uri, "can't set both account uri and podcast")
    end
  end

end
