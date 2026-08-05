module Apple
  class SyncLog < ::SyncLog
    with_options if: -> { feeder_type == "episodes" } do
      validates :feeder_id,
        uniqueness: {
          scope: [:integration, :feeder_type, :external_show_id],
          message: "already has an Apple episode sync log"
        }
      validates :external_show_id, presence: true
    end

    def self.sti_name
      "apple"
    end

    def self.log!(attrs)
      super(attrs.merge(integration: :apple))
    end
  end
end
