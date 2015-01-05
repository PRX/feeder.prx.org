Dotenv.load

def use_webmock?
  ENV['USE_WEBMOCK'].nil? || (ENV['USE_WEBMOCK'] == 'true')
end

ENV["RAILS_ENV"] ||= "test"

require 'simplecov' if !ENV['GUARD'] || ENV['GUARD_COVERAGE']

if ENV['TRAVIS']
  require 'codeclimate-test-reporter'
  require 'coveralls'
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
    SimpleCov.formatter,
    Coveralls::SimpleCov::Formatter,
    CodeClimate::TestReporter::Formatter
  ]
end

require File.expand_path("../../config/environment", __FILE__)

require 'rails/test_help'
require 'factory_girl'
require 'minitest/reporters'
require 'minitest/autorun'
require 'minitest/spec'
require 'webmock/minitest'
require 'minitest/pride'

WebMock.allow_net_connect! unless use_webmock?

class ActiveSupport::TestCase
  include FactoryGirl::Syntax::Methods
end

def json_file(name)
  test_file("/fixtures/#{name}.json")
end

def test_file(path)
  File.read( File.dirname(__FILE__) + path)
end

def stub_requests_to_prx_cms
  if use_webmock?
    stub_request(:get, 'https://hal.prx.org/api/v1').
      to_return(status: 200, body: json_file(:prx_root), headers: {})

    stub_request(:get, 'https://hal.prx.org/api/v1/stories/87683').
      to_return(status: 200, body: json_file(:prx_story), headers: {})

    stub_request(:get, 'https://hal.prx.org/api/v1/accounts/45139').
      to_return(status: 200, body: json_file(:prx_account), headers: {})

    stub_request(:get, 'https://hal.prx.org/api/v1/audio_files/451642').
      to_return(status: 200, body: json_file(:prx_audio_file), headers: {})

    stub_request(:get, "https://hal.prx.org/api/v1/story_images/203874").
      to_return(status: 200, body: json_file(:prx_story_image), headers: {})
  end
end
