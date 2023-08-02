API_WAIT_INTERVAL = 2.seconds
API_WAIT_TIMEOUT = 5.minutes

module Apple
  module ApiWaiting
    extend ActiveSupport::Concern
    included do
      def self.wait_for(remaining_records, wait_timeout: API_WAIT_TIMEOUT, wait_interval: API_WAIT_INTERVAL)
        t_beg = Time.now.utc

        waited = 0
        loop do
          # All done, return `timeout == false`
          break [false, []] if remaining_records.empty?
          # Return `timeout == true` if we've waited too long
          break [true, remaining_records] if waited > wait_timeout

          sleep(wait_interval)

          waited = Time.now.utc - t_beg
          Rails.logger.info(".wait_for", {remaining_record_count: remaining_records.count, have_waited: waited})

          remaining_records = yield(remaining_records)
        end
      end
    end
  end
end
