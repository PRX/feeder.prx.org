require 'test_helper'

describe Api::MediaResourceRepresenter do
  let(:media_resource) { MediaResource.new }
  let(:representer) { Api::MediaResourceRepresenter.new(media_resource) }

  it 'includes the href' do
    media_resource.stub(:href, 'url') do
      representer.as_json['href'].must_equal 'url'
    end
  end

  it 'includes the type' do
    media_resource.stub(:mime_type, 'audio/taco') do
      representer.as_json['type'].must_equal 'audio/taco'
    end
  end

  it 'includes the size' do
    media_resource.stub(:file_size, 123456) do
      representer.as_json['size'].must_equal 123456
    end
  end

  it 'includes the duration' do
    media_resource.stub(:duration, 1234) do
      representer.as_json['duration'].must_equal 1234
    end
  end
end
