# frozen_string_literal: true

describe Apple::ApiResponse do

  let(:ok_http_resp) do
    res = Net::HTTPResponse.new(1.0, 200, "OK")

    res = Net::HTTPOK.new(nil, nil, nil)
    res.body = '{"foo": 123}'
    res
  end

  it 'returns parsed json from http ok reponses' do
    assert_equal Apple::ApiResponse.json(ok_http_resp), {'foo' => 123}
  end
end
