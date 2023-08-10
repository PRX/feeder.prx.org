# frozen_string_literal: true

module AdvisoryLocks
  extend ActiveSupport::Concern

  PODCAST_PUBLISHING_ADVISORY_LOCK_TYPE = 1

  def with_advisory_lock(lock_type)
    raise "Cannot lock unpersisted instances" unless persisted? && id.present?
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_lock(#{lock_type}, #{id})")
    ActiveRecord::Base.uncached do
      yield
    end
  ensure
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{lock_type}, #{id})")
  end
end
