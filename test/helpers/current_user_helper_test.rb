require "test_helper"

class TestHelper
  attr_accessor :current_user, :current_user_apps, :current_user_info
  include CurrentUserHelper
end

describe CurrentUserHelper do
  let(:helper) { TestHelper.new }

  describe "#current_user_app?" do
    it "makes sure there is a current user" do
      helper.current_user = nil
      refute helper.current_user_app?("foo")
      refute helper.current_user_app?("bar")
    end

    it "determines if you have an app or not" do
      helper.current_user = {}
      helper.current_user_apps = {
        "app for BAR" => "https://bar.prx.org",
        "and then BAZ" => "https://baz.staging.prx.tech"
      }

      refute helper.current_user_app?("foo")
      assert helper.current_user_app?("bar")
      assert helper.current_user_app?("baz")
    end
  end

  describe "#current_user_app" do
    it "returns app urls" do
      helper.current_user = {}
      helper.current_user_apps = {
        "dev domain" => "https://foo.prx.dev",
        "real Bar domain" => "https://bar.prx.org",
        "staging Baz domain" => "https://baz.staging.prx.tech"
      }

      assert_nil helper.current_user_app("foo")
      assert_equal "https://bar.prx.org", helper.current_user_app("bar")
      assert_equal "https://baz.staging.prx.tech", helper.current_user_app("baz")
    end
  end

  describe "#current_user_id_profile" do
    it "returns the ID host" do
      assert_includes helper.current_user_id_profile, PrxAuth::Rails.configuration.id_host
    end
  end

  describe "#current_user_image?" do
    it "checks if the user has an image" do
      refute helper.current_user_image?

      helper.current_user = {}
      helper.current_user_info = {"image_href" => ""}
      refute helper.current_user_image?

      helper.current_user_info = {"image_href" => "http://some.where/img"}
      assert helper.current_user_image?
    end
  end

  describe "#current_user_image" do
    it "returns the user image url" do
      helper.current_user_info = {"image_href" => "http://some.where/img"}
      assert_equal "http://some.where/img", helper.current_user_image
    end
  end
end
