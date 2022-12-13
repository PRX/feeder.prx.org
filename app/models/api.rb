class Api
  include HalApi::RepresentedModel

  attr_accessor :version

  def self.version(version)
    new(version)
  end

  def initialize(version)
    @version = version
    self.is_root_resource = true
  end

  def to_model
    self
  end

  def persisted?
    false
  end

  def cache_key
    "api/#{version}-#{updated_at.utc.to_i}"
  end

  def updated_at
    File.mtime(__FILE__)
  end
end
