class HlsVideo < MediaResource
  validates :medium, inclusion: {in: %w[video]}, if: :status_complete?
  validates :duration, numericality: {greater_than: 0}, if: :status_complete?
  validate :validate_segmentation
end
