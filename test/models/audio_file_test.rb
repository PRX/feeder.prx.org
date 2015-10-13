require 'test_helper'

describe AudioFile do
  it 'jsons correctly' do
    AudioFile.new(
      url: 'url',
      type: 'type',
      size: 5123,
      duration: 123
    ).as_json.must_equal(
      href: 'url',
      type: 'type',
      size: 5123,
      duration: 123
    )
  end
end
