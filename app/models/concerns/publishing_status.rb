require "active_support/concern"

module PublishingStatus
  extend ActiveSupport::Concern

  STATUSES = ["draft", "scheduled", "published"]

  included do
    validate :validate_publishing_status
  end

  def publishing_status
    @publishing_status ||=
      if published_at.nil?
        "draft"
      elsif published_at > Time.now
        "scheduled"
      else
        "published"
      end
  end

  def publishing_status_was
    if published_at_was.nil?
      "draft"
    elsif published_at_was > Time.now
      "scheduled"
    else
      "published"
    end
  end

  def publishing_status=(value)
    @publishing_status = value

    if value == "draft"
      self.released_at = published_at if published_at.present?
      self.published_at = nil
    elsif value == "scheduled"
      self.published_at = released_at
    elsif value == "published"
      if publishing_status_was == "draft" && (released_at.blank? || released_at > Time.now)
        self.released_at = Time.now
      end
      self.published_at = released_at
    end
  end

  def validate_publishing_status
    return if @publishing_status.nil? || @publishing_status == "draft"

    # check desired status vs timestamp
    if published_at.blank?
      errors.add(:published_at, "can't be blank")
      errors.add(:released_at_date, "can't be blank")
    elsif @publishing_status == "scheduled" && published_at <= Time.now
      errors.add(:published_at, "can't be in the past")
      errors.add(:released_at_date, "can't be in the past")
    elsif @publishing_status == "published" && published_at > Time.now
      errors.add(:published_at, "can't be in the future")
      errors.add(:released_at_date, "can't be in the future")
    end
  end
end
