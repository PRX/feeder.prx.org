require 'test_helper'

describe Api::PodcastRepresenter do

  let(:podcast) { create(:podcast) }
  let(:representer) { Api::PodcastRepresenter.new(podcast) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'includes basic properties' do
    # puts podcast.itunes_categories.inspect
    # puts json
    # json.wont_be_nil
    json['path'].must_equal 'jjgo'
    json['prxUri'].must_match /\/api\/v1\/series\//
    json['itunesCategories'].wont_be_nil
  end
end
