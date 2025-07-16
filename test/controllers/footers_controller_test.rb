require "test_helper"

class FootersControllerTest < ActionDispatch::IntegrationTest
  test "should get terms_of_service" do
    get terms_of_service_url
    assert_response :success
  end
end
