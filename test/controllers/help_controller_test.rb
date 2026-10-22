require "test_helper"

class HelpControllerTest < ActionDispatch::IntegrationTest
  test "help requires sign in" do
    get help_path
    assert_redirected_to new_session_path
    get help_article_path("register")
    assert_redirected_to new_session_path
  end

  test "staff get a searchable guide without administrator documents" do
    sign_in_as(users(:one))
    get help_path
    assert_response :success
    assert_equal "help", inertia_props["view"]
    assert_nil inertia_props["article"]
    guides = inertia_props.fetch("guides")
    assert guides.any? { |guide| guide["slug"] == "register" }
    assert guides.none? { |guide| guide["slug"] == "shopify" }
    assert_includes guides.find { |guide| guide["slug"] == "payments" }.fetch("search_text"), "three cents"
  end

  test "article includes its sections and a feature link" do
    sign_in_as(users(:one))
    get help_article_path("register")
    assert_response :success
    assert_equal "Using the register", inertia_props.dig("article", "title")
    assert_equal "scan-and-search", inertia_props.dig("article", "sections", 0, "id")
    assert_equal register_path, inertia_props.dig("actions", "feature")
  end

  test "staff cannot fetch hidden administrator articles or launch admin settings" do
    sign_in_as(users(:one))
    get help_article_path("shopify")
    assert_response :not_found
    get help_article_path("tax-codes")
    assert_response :success
    assert_nil inertia_props.dig("actions", "feature")
  end

  test "administrators can open setup articles and feature links" do
    sign_in_as(users(:admin))
    get help_article_path("shopify")
    assert_response :success
    assert_equal admin_shopify_path, inertia_props.dig("actions", "feature")
  end

  test "unknown article slugs return not found" do
    sign_in_as(users(:one))
    get help_article_path("unknown-document")
    assert_response :not_found
  end

  test "ordinary register requests get contextual help without loading documents" do
    sign_in_as(users(:one))
    Help::Guide.stub(:all, -> { raise "Help documents should not load for register requests" }) do
      get register_path
    end
    assert_response :success
    assert_equal help_article_path("register"), inertia_props.dig("help", "context")
    assert_equal help_path, inertia_props.dig("paths", "help")
  end
end
