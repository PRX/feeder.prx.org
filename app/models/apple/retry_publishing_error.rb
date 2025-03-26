module Apple
  class RetryPublishingError < StandardError
    def initialize(message)
      super(message)
    end
  end
end