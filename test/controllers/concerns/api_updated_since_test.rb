require "test_helper"

class ApiUpdatedSinceTestController < Api::BaseController
  include ApiUpdatedSince

  attr_accessor :since_string, :globally_authorized

  def authorization
    OpenStruct.new(globally_authorized?: !!globally_authorized)
  end

  def params
    {since: since_string}
  end
end

describe ApiUpdatedSince do
  let(:controller) { ApiUpdatedSinceTestController.new }

  it "defaults to nothing" do
    assert_equal controller.updated_since_with_deleted?, false
    assert_equal controller.updated_since?, false
    assert_nil controller.updated_since
  end

  it "checks for globally authorized users" do
    controller.since_string = "2018-01-10"
    controller.globally_authorized = true
    assert_equal controller.updated_since_with_deleted?, true
    assert_equal controller.updated_since?, true
  end

  it "parses since params" do
    controller.since_string = "2018-01-10"
    assert_equal controller.updated_since_with_deleted?, false
    assert_equal controller.updated_since?, true
    assert_equal controller.updated_since, DateTime.parse("2018-01-10T00:00:00 +0000")
  end

  it "handles insanity" do
    controller.since_string = "anything"
    assert_equal controller.updated_since?, false
    assert_nil controller.updated_since
  end
end
