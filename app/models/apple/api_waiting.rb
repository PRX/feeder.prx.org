module Apple
  module ApiWaiting
    API_WAIT_INTERVAL = 2.seconds
    API_WAIT_TIMEOUT = 5.minutes

    extend ActiveSupport::Concern
    included do
      def self.wait_for(remaining_records)
        t_beg = Time.now.utc
        loop do
          # TODO: handle timeout
          break [false, remaining_records] if Time.now.utc - t_beg > self::API_WAIT_TIMEOUT

          remaining_records = yield(remaining_records)

          break [true, []] if remaining_records.empty?

          sleep(self::API_WAIT_INTERVAL)
        end
      end
    end
  end
end
