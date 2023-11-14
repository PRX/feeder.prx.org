require "test_helper"

describe Api::MediaResourceRepresenter do
  let(:media_resource) { MediaResource.new }
  let(:representer) { Api::MediaResourceRepresenter.new(media_resource) }

  it "does not include the href" do
    media_resource.stub(:href, "url") do
      # TODO: deprecate
      # assert_nil representer.as_json["href"]
    end
  end

  it "includes the type" do
    media_resource.stub(:mime_type, "audio/taco") do
      assert_equal representer.as_json["type"], "audio/taco"
    end
  end

  it "includes the size" do
    media_resource.stub(:file_size, 123456) do
      assert_equal representer.as_json["size"], 123456
    end
  end

  it "includes the duration" do
    media_resource.stub(:duration, 1234) do
      assert_equal representer.as_json["duration"], 1234
    end
  end
end
