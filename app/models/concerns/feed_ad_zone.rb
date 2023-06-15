require "active_support/concern"

module FeedAdZone
  extend ActiveSupport::Concern

  ALL_ZONES = ["billboard", "house", "ad", "sonic_id"]

  def billboard
    check("billboard")
  end

  def billboard=(val)
    if checked?(val)
      add_zone("billboard")
    else
      remove_zone("billboard")
    end
  end

  def house
    check("house")
  end

  def house=(val)
    if checked?(val)
      add_zone("house")
    else
      remove_zone("house")
    end
  end

  def paid
    check("ad")
  end

  def paid=(val)
    if checked?(val)
      add_zone("ad")
    else
      remove_zone("ad")
    end
  end

  def sonic_id
    check("sonic_id")
  end

  def sonic_id=(val)
    if checked?(val)
      add_zone("sonic_id")
    else
      remove_zone("sonic_id")
    end
  end

  private

  def add_zone(zone)
    return if self.include_zones.nil?

    self.include_zones << zone unless self.include_zones.include?(zone)
    if self.include_zones.count == 4
      self.include_zones = nil
    end
  end

  def remove_zone(zone)
    if self.include_zones.nil?
      self.include_zones = ALL_ZONES
    end
    self.include_zones.reject! { |z| z == zone }
  end

  def checked?(val)
    val == "1"
  end

  def check(zone)
    if self.include_zones.nil?
      "1"
    else
      self.include_zones.include?(zone) ? "1" : "0"
    end
  end
end
