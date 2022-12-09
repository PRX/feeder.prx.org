require 'simplecov'
SimpleCov.start 'rails'

ENV['CMS_HOST']        = 'cms.prx.org'
ENV['FEEDER_HOST']     = 'feeder.prx.org'
ENV['FEEDER_CDN_HOST'] = 'f.prxu.org'
ENV['FEEDER_CDN_PRIVATE_HOST'] = 'p.prxu.org'
ENV['ID_HOST']         = 'id.prx.org'
ENV['META_HOST']       = 'meta.prx.org'
ENV['PRX_HOST']        = 'www.prx.org'
ENV['DOVETAIL_HOST']   = 'dovetail.prxu.org'
ENV['FEEDER_STORAGE_BUCKET'] = 'test-prx-feed'
ENV['ANNOUNCE_RESOURCE_PREFIX'] = 'test'

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

require 'minitest/pride'
require 'minitest/autorun'
require 'factory_bot'
require 'webmock/minitest'
# require 'announce/testing'

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  include FactoryBot::Syntax::Methods
end

# MiniTest
class MiniTest::Unit::TestCase
  include FactoryBot::Syntax::Methods
end

# MiniTest::Spec
class MiniTest::Spec
  include FactoryBot::Syntax::Methods
end

def json_file(name)
  test_file("/fixtures/#{name}.json")
end

def test_file(path)
  File.read(File.dirname(__FILE__) + path)
end

def stub_requests_to_prx_cms
  stub_request(:get, 'https://cms.prx.org/api/v1').
    to_return(status: 200, body: json_file(:prx_root), headers: {})

  stub_request(:get, 'https://cms.prx.org/api/v1/stories/87683').
    to_return(status: 200, body: json_file(:prx_story), headers: {})

  stub_request(:get, 'https://cms.prx.org/api/v1/accounts/45139').
    to_return(status: 200, body: json_file(:prx_account), headers: {})

  stub_request(:get, 'https://cms.prx.org/api/v1/audio_files/451642').
    to_return(status: 200, body: json_file(:prx_audio_file), headers: {})

  stub_request(:get, 'https://cms.prx.org/api/v1/story_images/203874').
    to_return(status: 200, body: json_file(:prx_story_image), headers: {})
end

class SnsMock
  attr_accessor :message

  def publish(params)
    self.message = JSON.parse(params[:message]).with_indifferent_access
    {
      message_id: 'whatever'
    }
  end
end

class StubToken < PrxAuth::Rails::Token
  @@fake_user_id = 0

  def initialize(res, scopes, explicit_user_id = nil)
    scopes = Array.wrap(scopes).map(&:to_s).join(' ')
    super(Rack::PrxAuth::TokenData.new({
      'scope' => scopes,
      'aur' => { res.to_s => scopes },
      'sub' => explicit_user_id || (@@fake_user_id += 1)
    }))
  end
end
