class Feed < ActiveRecord::Base
  OVERRIDES = %w[title display_episodes_count itunes_block itunes_type].freeze
  belongs_to :podcast
  serialize :overrides, HashSerializer

  before_validation :filter_overrides

  def filter_overrides
    self.overrides = (overrides || {}).with_indifferent_access.slice(*OVERRIDES)
  end

  def overridden?(key)
    k = key.to_s
    OVERRIDES.include?(k) && overrides.keys.map(&:to_s).include?(k)
  end
end
