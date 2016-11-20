ENV['RAILS_ENV'] = 'test'

require 'simplecov'
SimpleCov.start 'rails'

if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!
end

Dotenv.load

require File.expand_path("../../config/environment", __FILE__)
require 'rails/test_help'
require 'minitest/pride'
require 'minitest/autorun'
require 'factory_girl'
require 'webmock/minitest'
require 'announce/testing'

def use_webmock?
  ENV['USE_WEBMOCK'].nil? || (ENV['USE_WEBMOCK'] == 'true')
end
WebMock.allow_net_connect! unless use_webmock?

include Announce::Testing
reset_announce

class ActiveSupport::TestCase
  include FactoryGirl::Syntax::Methods
end

# MiniTest
class MiniTest::Unit::TestCase
  include FactoryGirl::Syntax::Methods
end

# MiniTest::Spec
class MiniTest::Spec
  include FactoryGirl::Syntax::Methods
end

def json_file(name)
  test_file("/fixtures/#{name}.json")
end

def test_file(path)
  File.read( File.dirname(__FILE__) + path)
end

def stub_requests_to_prx_cms
  return unless use_webmock?

  stub_request(:get, 'https://cms.prx.org/api/v1').
    to_return(status: 200, body: json_file(:prx_root), headers: {})

  stub_request(:get, 'https://cms.prx.org/api/v1/stories/87683').
    to_return(status: 200, body: json_file(:prx_story), headers: {})

  stub_request(:get, 'https://cms.prx.org/api/v1/accounts/45139').
    to_return(status: 200, body: json_file(:prx_account), headers: {})

  stub_request(:get, 'https://cms.prx.org/api/v1/audio_files/451642').
    to_return(status: 200, body: json_file(:prx_audio_file), headers: {})

  stub_request(:get, "https://cms.prx.org/api/v1/story_images/203874").
    to_return(status: 200, body: json_file(:prx_story_image), headers: {})
end

class SqsMock
  def initialize(id = nil)
    @id = id || '11111111'
  end

  def create_job(j)
    j[:job][:id] = @id
    j
  end
end

Minitest::Expectations.infect_an_assertion :assert_operator, :must_allow, :reverse
Minitest::Expectations.infect_an_assertion :refute_operator, :wont_allow, :reverse

StubToken = Struct.new(:resource, :scopes, :user_id)
class StubToken
  @@fake_user_id = 0

  def initialize(res, scopes, explicit_user_id = nil)
    if explicit_user_id
      super(res.to_s, scopes, explicit_user_id)
    else
      super(res.to_s, scopes, @@fake_user_id += 1)
    end
  end

  def authorized?(r, s = nil)
    resource == r.to_s && (s.nil? || scopes.include?(s.to_s))
  end
end
