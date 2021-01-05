require 'test_helper'

describe Api::BaseController do

  it 'should show entrypoint' do
    get :entrypoint, api_version: 'v1', format: 'json'
    assert_response :success
  end

  it "determines show action options for roar" do
    @controller.class.resource_representer = 'rr'
    assert_equal @controller.send(:show_options)[:represent_with], 'rr'
  end

  it "can parse a zoom parameter" do
    @controller.params[:zoom] = "a,test"
    assert_equal @controller.send(:zoom_param), ['a', 'test']
  end

  it 'has no content for options requests' do
    process :options, 'OPTIONS', api_version: 'v1', any: '1'
    assert_equal response.status, 204
  end
end
