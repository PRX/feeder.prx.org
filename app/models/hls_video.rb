class HlsVideo < MediaResource
  validates :medium, inclusion: {in: %w[video]}, if: :status_complete?
  validates :duration, numericality: {greater_than: 0}, if: :status_complete?

  def max_file_size
    10.gigabytes
  end
end
