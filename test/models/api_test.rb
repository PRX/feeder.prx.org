require 'test_helper'

describe Api do
  let(:api) { Api.version('1.0') }

  it 'create an api with a version' do
    api.version.must_equal '1.0'
  end

  it 'implements to_model' do
    api.to_model.must_equal api
  end

  it 'is not persisted' do
    api.wont_be :persisted?
  end

  it 'has a cache key' do
    api.cache_key.wont_be_nil
    api.cache_key.must_match /^api\/1.0-/
  end

  it 'has an updated_at date' do
    api.updated_at.wont_be_nil
    api.updated_at.must_be_instance_of Time
  end

  it 'always a root resource' do
    api.must_be :is_root_resource
  end
end
