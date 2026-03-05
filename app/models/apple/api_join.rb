# frozen_string_literal: true

module Apple
  module ApiJoin
    module_function

    # assumes the apple_episode_id is present on the request metadata
    def join_on_apple_episode_id(resources, results, left_join: false)
      join_on("apple_episode_id", resources, results, left_join: left_join)
    end

    def join_on(id_attribute_key, resources, results, left_join: false)
      (resources_by_id, results_by_id) = one_to_one_lookup(id_attribute_key, resources, results)

      resource_key_set = Set.new(resources_by_id.keys)
      result_key_set = Set.new(results_by_id.keys)

      if left_join
        raise "Result keys are not a subset of resource keys" unless result_key_set.subset?(resource_key_set)
      else
        raise "Join key mismatch" unless resource_key_set == result_key_set
      end

      resources_by_id.map do |join_key, resource|
        result = results_by_id.fetch(join_key, nil)
        [resource, result]
      end
    end

    def join_many_on(id_attribute_key, resources, results, left_join: false)
      (resources_by_id, results_by_id) = one_to_many_lookup(id_attribute_key, resources, results)

      resource_key_set = Set.new(resources_by_id.keys)
      result_key_set = Set.new(results_by_id.keys)

      if left_join
        raise "Result keys are not a subset of resource keys" unless result_key_set.subset?(resource_key_set)
      else
        raise "Join key mismatch" unless resource_key_set == result_key_set
      end

      resources_by_id.map do |join_key, resource|
        result = results_by_id.fetch(join_key, nil)
        [resource, result]
      end
    end

    def one_to_one_lookup(id_attribute_key, resources, results)
      (resources_by_id, results_by_id) = one_to_many_lookup(id_attribute_key, resources, results)

      if results_by_id.values.any? { |v| v.length > 1 }
        raise "Duplicate results found for '#{id_attribute_key}'"
      end

      [resources_by_id, results_by_id.transform_values(&:first)]
    end

    def one_to_many_lookup(id_attribute_key, resources, results)
      raise "Resource missing join attribute" if resources.any? { |r| !r.respond_to?(id_attribute_key) }
      raise "Result missing join attribute" if results.any? { |r| !r.dig("request_metadata", id_attribute_key).present? }

      (resources_by_id, results_by_id) = [resources.group_by { |resource| resource.send(id_attribute_key) },
        results.group_by { |result| result.dig("request_metadata", id_attribute_key) }]

      if resources_by_id.values.any? { |v| v.length > 1 }
        raise "Duplicate resources found for key '#{id_attribute_key}'"
      end

      # Joining on the resources which are uniq here
      [resources_by_id.transform_values(&:first), results_by_id]
    end
  end
end
