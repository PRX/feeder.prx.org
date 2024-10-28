module Apple
  class EpisodeDeliveryStatus < ApplicationRecord
    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"

    def self.change_log(apple_episode_delivery_statuses)
      return [] unless apple_episode_delivery_statuses&.any?

      statuses = apple_episode_delivery_statuses.to_a
      changes = []

      tracked_attributes = column_names - ["id", "created_at"]

      latest_values = {}

      statuses.reverse_each do |status|
        tracked_attributes.each do |attr|
          value = status.send(attr)

          # Only record the change if we haven't seen this attribute before
          # or if the value is different from the most recent one
          if !latest_values.key?(attr) || latest_values[attr] != value
            latest_values[attr] = value

            # Format the change message
            message = format_change_message(attr, value, status.created_at)
            changes.unshift(message) unless message.nil?
          end
        end
      end

      changes
    end

    def self.format_change_message(attribute, value, timestamp)
      return nil if value.nil?

      formatted_time = timestamp.strftime("%Y-%m-%d %H:%M:%S")
      "#{formatted_time}: #{attribute.humanize} changed to #{value}"
    end

    def self.measure_asset_processing_duration(apple_episode_delivery_statuses, relative_timestamp)
      return [] unless apple_episode_delivery_statuses&.any?

      statuses = apple_episode_delivery_statuses.to_a

      last_status = statuses.shift

      return [nil, measure_asset_processing_duration(statuses, last_status.created_at)].flatten unless last_status&.asset_processing_attempts.to_i.positive?

      end_status = while status = statuses.shift
        break status if status.asset_processing_attempts.to_i.zero?
      end

      return [nil].flatten unless end_status

      [
        relative_timestamp - end_status.created_at,
        measure_asset_processing_duration(statuses, end_status.created_at)
      ].flatten
    end

    def self.update_status(episode, attrs)
      new_status = (episode.apple_episode_delivery_status&.dup || default_status(episode))
      new_status.assign_attributes(attrs)
      new_status.save!
      episode.apple_episode_delivery_statuses.reset
      new_status
    end

    def self.default_status(episode)
      new(episode: episode)
    end

    def increment_asset_wait
      self.class.update_status(episode, asset_processing_attempts: (asset_processing_attempts || 0) + 1)
    end

    def reset_asset_wait
      self.class.update_status(episode, asset_processing_attempts: 0)
    end
  end
end
