module Megaphone
  class Cuepoint
    include Megaphone::Model

    CUEPOINT_TYPES = %i[preroll midroll postroll remove]

    AD_SOURCES = %i[auto promo span]

    CREATE_REQUIRED = %i[cuepoint_type ad_count start_time ad_sources]

    # max_duration is undocumented, but it works to set as a # of seconds
    CREATE_ATTRIBUTES = CREATE_REQUIRED + %i[title end_time action is_active offset notes max_duration]

    ALL_ATTRIBUTES = CREATE_ATTRIBUTES

    attr_accessor(*ALL_ATTRIBUTES)

    validates_presence_of CREATE_REQUIRED

    def self.from_placement_and_media(placement, media)
      cuepoints = []
      current_cuepoint = nil
      original_duration = 0
      original_count = 0
      placement.zones.each do |zone|
        # if this is an ad zone, add it to the cue point
        if ["ad", "house", "sonic_id", "billboard"].include?(zone[:type])
          if current_cuepoint
            current_cuepoint.ad_count = current_cuepoint.ad_count + 1
            current_cuepoint.ad_sources << source_for_zone(zone)
          else
            section = (placement.sections || [])[original_count] || {}
            current_cuepoint = new(
              cuepoint_type: "#{section[:type] || zone[:section]}roll",
              ad_count: 1,
              start_time: original_duration,
              ad_sources: [source_for_zone(zone)],
              action: :insert,
              is_active: true,
              max_duration: section[:max_duration]
            )
            cuepoints << current_cuepoint
          end
        elsif zone[:type] == "original"
          current_cuepoint = nil
          original_duration += media[original_count].duration
          original_count += 1
        end
      end
      cuepoints
    end

    def self.source_for_zone(zone)
      if ["sonic_id", "house"].include?(zone[:type])
        :promo
      else
        :auto
      end
    end

    def as_json_for_create
      as_json(only: CREATE_ATTRIBUTES.map(&:to_s))
    end
  end
end
