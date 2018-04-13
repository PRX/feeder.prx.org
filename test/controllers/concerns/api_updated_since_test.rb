require 'test_helper'

describe ApiUpdatedSince do

  class ApiUpdatedSinceTestController < Api::BaseController
    include ApiUpdatedSince
    attr_accessor :since_string
    def params
      { since: since_string }
    end
  end

  let(:controller) { ApiUpdatedSinceTestController.new }

  it 'defaults to nothing' do
    controller.updated_since?.must_equal false
    controller.updated_since.must_be_nil
  end

  it 'parses since params' do
    controller.since_string = '2018-01-10'
    controller.updated_since?.must_equal true
    controller.updated_since.must_equal DateTime.parse('2018-01-10T00:00:00 +0000')
  end

  it 'handles insanity' do
    controller.since_string = 'anything'
    controller.updated_since?.must_equal false
    controller.updated_since.must_be_nil
  end
end
