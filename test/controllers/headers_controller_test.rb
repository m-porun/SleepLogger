require "test_helper"

class HeadersControllerTest < ActionDispatch::IntegrationTest
  test "should get how_to_use" do
    get headers_how_to_use_url
    assert_response :success
  end
end
