ENV["RAILS_ENV"] = "test"

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
require 'minitest/pride'

class ActiveSupport::TestCase
  include FactoryGirl::Syntax::Methods
end

class MiniTest::Spec
  include FactoryGirl::Syntax::Methods
end
