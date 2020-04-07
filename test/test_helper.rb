ENV['RAILS_ENV'] = 'test'

require 'simplecov'
SimpleCov.start 'rails'

if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!
end

ENV['CMS_HOST']        = 'cms.prx.org'
ENV['FEEDER_HOST']     = 'feeder.prx.org'
ENV['FEEDER_CDN_HOST'] = 'f.prxu.org'
ENV['ID_HOST']         = 'id.prx.org'
ENV['META_HOST']       = 'meta.prx.org'
ENV['PRX_HOST']        = 'www.prx.org'
ENV['DOVETAIL_HOST']   = 'dovetail.prxu.org'
ENV['FEEDER_STORAGE_BUCKET'] = 'test-prx-feed'
ENV['PORTER_SNS_TOPIC'] = nil

require File.expand_path("../../config/environment", __FILE__)
require 'rails/test_help'
require 'minitest/pride'
require 'minitest/autorun'
require 'factory_girl'
require 'webmock/minitest'
require 'announce/testing'

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

class SnsMock
  attr_accessor :message

  def publish(params)
    self.message = JSON.parse(params[:message]).with_indifferent_access
    {
      message_id: 'whatever'
    }
  end
end

Minitest::Expectations.infect_an_assertion :assert_operator, :must_allow, :reverse
Minitest::Expectations.infect_an_assertion :refute_operator, :wont_allow, :reverse

class StubToken < Rack::PrxAuth::TokenData
  @@fake_user_id = 0

  attr_reader :resource, :scopes, :user_id

  def initialize(res, scopes, explicit_user_id = nil)
    @resource = res.to_s
    @scopes = scopes
    @user_id = explicit_user_id || (@@fake_user_id += 1)
  end

  def attributes
    { sub: @@fake_user_id, aur: { resource => scopes }, scope: 'read write purchase sell delete' }
  end

  def authorized_resources
    attributes[:aur]
  end

  def authorized?(r, s = nil)
    resource == r.to_s && (s.nil? || scopes.include?(s.to_s))
  end
end
