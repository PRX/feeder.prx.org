module Integrations
  module Base
    class Episode
      attr_accessor :feeder_episode

      def synced_with_integration?
        raise NotImplementedError, "Subclasses must implement synced_with_integration?"
      end

      def integration_new?
        raise NotImplementedError, "Subclasses must implement integration_new?"
      end

      def archived?
        raise NotImplementedError, "Subclasses must implement archived?"
      end

      def video_content_type?
        feeder_episode.video_content_type?
      end

      # Delegate methods to feeder_episode
      def method_missing(method_name, *arguments, &block)
        if feeder_episode.respond_to?(method_name)
          feeder_episode.send(method_name, *arguments, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        feeder_episode.respond_to?(method_name) || super
      end
    end
  end
end
