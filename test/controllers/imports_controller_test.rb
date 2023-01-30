require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  setup_current_user { build(:user) }
  setup { @podcast = create(:podcast) }

  test "should get index" do
    get podcast_imports_url(@podcast)
    assert_response :success
  end

  # test "should get new" do
  #   get new_import_url
  #   assert_response :success
  # end

  # test "should create import" do
  #   assert_difference("Import.count") do
  #     post imports_url, params: {import: {}}
  #   end

  #   assert_redirected_to import_url(Import.last)
  # end

  # test "should show import" do
  #   get import_url(@import)
  #   assert_response :success
  # end

  # test "should get edit" do
  #   get edit_import_url(@import)
  #   assert_response :success
  # end

  # test "should update import" do
  #   patch import_url(@import), params: {import: {}}
  #   assert_redirected_to import_url(@import)
  # end

  # test "should destroy import" do
  #   assert_difference("Import.count", -1) do
  #     delete import_url(@import)
  #   end

  #   assert_redirected_to imports_url
  # end
end
