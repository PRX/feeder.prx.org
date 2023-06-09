require "active_support/concern"

module FeedAdZone
  extend ActiveSupport::Concern

  def add_zone(zone)
    include_zones << zone unless include_zones.include?(zone)
  end

  def remove_zone(zone)
    include_zones.reject! { |z| z == zone }
  end

  def billboard
    return unless include_zones.present?

    include_zones.include?("billboard") ? 1 : 0
  end

  def billboard=(val)
    self.include_zones ||= []

    if val == "1"
      add_zone("billboard")
    else
      remove_zone("billboard")
    end
  end

  def house
    return unless include_zones.present?

    include_zones.include?("house") ? 1 : 0
  end

  def house=(val)
    self.include_zones ||= []

    if val == "1"
      add_zone("house")
    else
      remove_zone("house")
    end
  end

  def paid
    return unless include_zones.present?

    include_zones.include?("ad") ? 1 : 0
  end

  def paid=(val)
    self.include_zones ||= []

    if val == "1"
      add_zone("ad")
    else
      remove_zone("ad")
    end
  end

  def sonic_id
    return unless include_zones.present?

    include_zones.include?("sonic_id") ? 1 : 0
  end

  def sonic_id=(val)
    self.include_zones ||= []

    if val == "1"
      add_zone("sonic_id")
    else
      remove_zone("sonic_id")
    end
  end
end
