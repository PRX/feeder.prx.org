class Feed < ActiveRecord::Base
  OVERRIDES = %w[title display_episodes_count itunes_block itunes_type]
  belongs_to :podcast
  serialize :overrides, HashSerializer

  def overridden?(key)
    k = key.to_s
    OVERRIDES.include?(k) && overrides.keys.map(&:to_s).include?(k)
  end
end
