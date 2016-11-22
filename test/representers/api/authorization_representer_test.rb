require 'test_helper'

describe Api::AuthorizationRepresenter do

  let(:account_id) { '123' }
  let(:token) { StubToken.new(account_id, ['member'], 456) }
  let(:authorization) { Authorization.new(token) }
  let(:representer) { Api::AuthorizationRepresenter.new(authorization) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'has link to episode' do
    json['_links']['prx:episode'].wont_be_nil
  end
end
