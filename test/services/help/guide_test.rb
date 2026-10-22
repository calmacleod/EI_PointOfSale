require "test_helper"

class Help::GuideTest < ActiveSupport::TestCase
  test "all documents have valid content and links" do
    guides = Help::Guide.all
    slugs = guides.map { |guide| guide.fetch("slug") }
    assert_equal slugs.uniq, slugs
    assert_operator guides.size, :>=, 20

    guides.each do |guide|
      %w[title summary category keywords].each { |key| assert guide.fetch(key).is_a?(String), "#{guide['slug']}: #{key}" }
      assert Help::Guide::FEATURE_PATHS.key?(guide.fetch("feature")), guide["slug"]
      assert_empty Array(guide["related"]) - slugs, "#{guide['slug']} has unknown related guides"
      ids = guide.fetch("sections").map { |section| section.fetch("id") }
      assert_equal ids.uniq, ids, guide["slug"]
      assert ids.all? { |id| id.match?(/\A[a-z0-9-]+\z/) }, guide["slug"]
      guide.fetch("sections").each do |section|
        assert section.fetch("title").present?
        assert section.slice("paragraphs", "steps", "bullets", "note").present?
        %w[paragraphs steps bullets].each do |key|
          assert Array(section[key]).all? { |text| text.is_a?(String) && text.present? }, "#{guide['slug']}: #{section['id']}: #{key}"
        end
        assert section["note"].nil? || section["note"].is_a?(String)
      end
    end
    assert_empty Help::Guide::TOPICS.values - slugs
  end

  test "staff see shared guides and administrators also see setup guides" do
    staff = Help::Guide.visible_to(users(:one))
    assert staff.any? { |guide| guide["slug"] == "register" }
    assert staff.none? { |guide| guide["audience"] == "admin" }
    assert Help::Guide.visible_to(users(:admin)).any? { |guide| guide["slug"] == "shopify" }
  end

  test "context uses a fixed mapping and defaults to getting started" do
    assert_equal "register", Help::Guide.topic_for("register")
    assert_equal "orders-and-refunds", Help::Guide.topic_for("orders")
    assert_equal "getting-started", Help::Guide.topic_for("unknown")
  end
end
