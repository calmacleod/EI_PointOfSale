# frozen_string_literal: true

require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:admin))
    @product = products(:dragon_shield_red)
  end

  # ── CRUD ────────────────────────────────────────────────────────────

  test "index lists products" do
    get products_path

    assert_response :success
    assert_includes response.body, @product.name
  end

  test "show displays product" do
    get product_path(@product)

    assert_response :success
    assert_includes response.body, @product.code
    assert_includes response.body, @product.name
  end

  test "new renders form" do
    get new_product_path

    assert_response :success
    assert_includes response.body, "New product"
  end

  test "create adds product" do
    assert_difference("Product.count", 1) do
      post products_path, params: {
        product: {
          code: "NEW-PROD-001",
          name: "New Test Product",
          selling_price: 9.99,
          purchase_price: 4.99,
          stock_level: 10
        }
      }
    end

    assert_redirected_to products_path
    created = Product.find_by(code: "NEW-PROD-001")
    assert_equal "New Test Product", created.name
    assert_equal 9.99, created.selling_price.to_f
  end

  test "edit renders form" do
    get edit_product_path(@product)

    assert_response :success
    assert_includes response.body, @product.code
  end

  test "update modifies product" do
    patch product_path(@product), params: {
      product: { selling_price: 16.99, stock_level: 50 }
    }

    assert_redirected_to product_path(@product)
    @product.reload
    assert_equal 16.99, @product.selling_price.to_f
    assert_equal 50, @product.stock_level
  end

  test "destroy discards product" do
    delete product_path(@product)

    assert_redirected_to products_path
    assert @product.reload.discarded?
  end

  # ── Image upload ────────────────────────────────────────────────────

  test "update attaches images" do
    image = fixture_file_upload("test_image.png", "image/png")

    assert_difference("@product.images.count", 1) do
      patch product_path(@product), params: {
        product: { images: [ image ] }
      }
    end

    assert_redirected_to product_path(@product)
    assert @product.reload.images.attached?
  end

  test "update with images preserves existing images" do
    @product.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "existing.png",
      content_type: "image/png"
    )
    assert_equal 1, @product.reload.images.count

    new_image = fixture_file_upload("test_image.png", "image/png")
    patch product_path(@product), params: {
      product: { images: [ new_image ] }
    }

    assert_redirected_to product_path(@product)
    assert_equal 2, @product.reload.images.count
  end

  # ── Image purge ─────────────────────────────────────────────────────

  test "purge_image removes a single image" do
    @product.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "to_remove.png",
      content_type: "image/png"
    )
    image_id = @product.images.last.id

    assert_difference("@product.images.count", -1) do
      delete purge_image_product_path(@product, image_id: image_id)
    end

    assert_redirected_to edit_product_path(@product)
  end

  # ── Authorization ───────────────────────────────────────────────────

  test "common user can view products" do
    sign_in_as(users(:one))

    get product_path(@product)
    assert_response :success
  end

  test "common user cannot edit product" do
    sign_in_as(users(:one))

    get edit_product_path(@product)
    assert_redirected_to root_path
  end

  test "common user cannot create product" do
    sign_in_as(users(:one))

    post products_path, params: {
      product: { code: "UNAUTH-001", name: "Unauthorized" }
    }
    assert_redirected_to root_path
  end

  test "common user cannot purge image" do
    sign_in_as(users(:one))
    @product.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "protected.png",
      content_type: "image/png"
    )
    image_id = @product.images.last.id

    delete purge_image_product_path(@product, image_id: image_id)
    assert_redirected_to root_path
    assert_equal 1, @product.reload.images.count
  end
end
