require "active_support/concern"

module EpisodeAdBreaks
  extend ActiveSupport::Concern

  included do
    alias_error_messages :ad_breaks, :segment_count
  end

  def ad_breaks
    segment_count - 1 if segment_count.present?
  end

  def ad_breaks=(num)
    self.segment_count = num.present? ? num.to_i + 1 : num
  end

  def ad_breaks_changed?
    segment_count_changed?
  end

  def ad_breaks_was
    segment_count_was - 1 if segment_count_was.present?
  end
end
