module Apple
  class SyncLog < ::SyncLog
    validates :feeder_id,
      uniqueness: {
        scope: [:integration, :feeder_type, :apple_show_id],
        message: "already has an Apple episode sync log"
      },
      if: :episodes?
    validates :apple_show_id, presence: true, if: :episodes?

    def self.sti_name
      "apple"
    end
  end
end
