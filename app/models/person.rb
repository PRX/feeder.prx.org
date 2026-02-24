class Person < ApplicationRecord
  enum :role, %w[host producer guest].to_enum_h, prefix: true, allow_nil: true

  belongs_to :owner, polymorphic: true, optional: true

  validates :name, presence: true
  validates :href, http_url: true
end
