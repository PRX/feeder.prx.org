# encoding: utf-8

class Api
  extend ActiveModel::Naming

  attr_accessor :version

  def self.version(version)
    new(version)
  end

  def initialize(version)
    @version = version
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

  def is_root_resource
    true
  end

  def is_root_resource=(is_root)
  end

  def show_curies
    true
  end
end
