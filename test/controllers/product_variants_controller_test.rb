# frozen_string_literal: true

require "test_helper"

class ProductVariantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:admin))
    @product = products(:dragon_shield)
    @variant = product_variants(:ds_red)
  end

  # ── CRUD ────────────────────────────────────────────────────────────

  test "show displays variant" do
    get product_product_variant_path(@product, @variant)

    assert_response :success
    assert_includes response.body, @variant.code
  end

  test "new renders form" do
    get new_product_product_variant_path(@product)

    assert_response :success
    assert_includes response.body, "Add variant"
  end

  test "create adds variant" do
    assert_difference("ProductVariant.count", 1) do
      post product_product_variants_path(@product), params: {
        product_variant: { code: "DS-MAT-WHT", name: "White", selling_price: 14.99 }
      }
    end

    assert_redirected_to edit_product_path(@product)
  end

  test "edit renders form" do
    get edit_product_product_variant_path(@product, @variant)

    assert_response :success
    assert_includes response.body, @variant.code
  end

  test "update modifies variant" do
    patch product_product_variant_path(@product, @variant), params: {
      product_variant: { selling_price: 16.99 }
    }

    assert_redirected_to edit_product_path(@product)
    assert_equal 16.99, @variant.reload.selling_price.to_f
  end

  # ── Image upload ────────────────────────────────────────────────────

  test "update attaches images" do
    image = fixture_file_upload("test_image.png", "image/png")

    assert_difference("@variant.images.count", 1) do
      patch product_product_variant_path(@product, @variant), params: {
        product_variant: { images: [ image ] }
      }
    end

    assert_redirected_to edit_product_path(@product)
    assert @variant.reload.images.attached?
  end

  test "update with images preserves existing images" do
    @variant.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "existing.png",
      content_type: "image/png"
    )
    assert_equal 1, @variant.reload.images.count

    new_image = fixture_file_upload("test_image.png", "image/png")

    patch product_product_variant_path(@product, @variant), params: {
      product_variant: { images: [ new_image ] }
    }

    assert_redirected_to edit_product_path(@product)
    assert_equal 2, @variant.reload.images.count
  end

  # ── Image purge ─────────────────────────────────────────────────────

  test "purge_image removes a single image" do
    @variant.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "to_remove.png",
      content_type: "image/png"
    )
    image_id = @variant.images.last.id

    assert_difference("@variant.images.count", -1) do
      delete purge_image_product_product_variant_path(@product, @variant, image_id: image_id)
    end

    assert_redirected_to edit_product_product_variant_path(@product, @variant)
  end

  # ── Authorization ───────────────────────────────────────────────────

  test "common user can view variant" do
    sign_in_as(users(:one))

    get product_product_variant_path(@product, @variant)

    assert_response :success
  end

  test "common user cannot edit variant" do
    sign_in_as(users(:one))

    get edit_product_product_variant_path(@product, @variant)

    assert_redirected_to root_path
  end

  test "common user cannot purge image" do
    sign_in_as(users(:one))
    @variant.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "protected.png",
      content_type: "image/png"
    )
    image_id = @variant.images.last.id

    delete purge_image_product_product_variant_path(@product, @variant, image_id: image_id)

    assert_redirected_to root_path
    assert_equal 1, @variant.reload.images.count
  end
end
