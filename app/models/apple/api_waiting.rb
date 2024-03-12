module Apple
  module ApiWaiting
    API_WAIT_INTERVAL = 2.seconds
    API_WAIT_TIMEOUT = 5.minutes

    extend ActiveSupport::Concern
    included do
      def self.current_time
        Time.now.utc
      end

      def self.wait_timed_out?(waited, wait_timeout)
        if waited > wait_timeout
          Rails.logger.info("Timed out waiting for Apple API to process", waited: waited, wait_timeout: wait_timeout)
          true
        else
          false
        end
      end

      def self.work_done?(remaining_records, waited, wait_timeout)
        if remaining_records.empty?
          Rails.logger.info("Done waiting for Apple Api work", waited: waited, wait_timeout: wait_timeout)
          true
        else
          false
        end
      end

      def self.wait_for(remaining_records, wait_timeout: API_WAIT_TIMEOUT, wait_interval: API_WAIT_INTERVAL)
        t_beg = current_time

        waited = 0
        loop do
          # All done, return `timeout == false`
          break [false, []] if work_done?(remaining_records, waited, wait_timeout)

          # Return `timeout == true` if we've waited too long
          break [true, remaining_records] if wait_timed_out?(waited, wait_timeout)

          sleep(wait_interval)

          waited = current_time - t_beg
          Rails.logger.info(".wait_for", {remaining_record_count: remaining_records.count, have_waited: waited})

          remaining_records = yield(remaining_records)
        end
      end
    end
  end
end
