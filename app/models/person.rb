class Person < ApplicationRecord
  enum :role, %w[host producer guest].to_enum_h, prefix: true, allow_nil: true

  belongs_to :owner, -> { with_deleted }, polymorphic: true, optional: true, touch: true

  validates :name, presence: true
  validates :href, http_url: true
end
