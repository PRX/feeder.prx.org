require "test_helper"

describe Api do
  let(:api) { Api.version("1.0") }

  it "create an api with a version" do
    assert_equal api.version, "1.0"
  end

  it "implements to_model" do
    assert_equal api.to_model, api
  end

  it "is not persisted" do
    refute api.persisted?
  end

  it "has a cache key" do
    refute_nil api.cache_key
    assert_match(/^api\/1.0-/, api.cache_key)
  end

  it "has an updated_at date" do
    refute_nil api.updated_at
    assert_instance_of Time, api.updated_at
  end

  it "always a root resource" do
    assert api.is_root_resource
  end
end
