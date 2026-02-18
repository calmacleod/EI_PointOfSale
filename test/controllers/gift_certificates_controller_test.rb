# frozen_string_literal: true

require "test_helper"

class GiftCertificatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
    @order = orders(:draft_order)
  end

  test "GET /orders/:id/gift_certificates/new renders form" do
    get new_order_gift_certificate_path(@order)
    assert_response :success
  end

  test "POST /orders/:id/gift_certificates creates gc and adds order line" do
    assert_difference [ "GiftCertificate.count", "OrderLine.count" ], 1 do
      post order_gift_certificates_path(@order), params: {
        gift_certificate: { initial_amount: "50.00" }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success

    gc = GiftCertificate.last
    assert gc.pending?
    assert_equal 50.00, gc.initial_amount
    assert_equal 50.00, gc.remaining_balance
    assert gc.code.starts_with?("GC-")

    line = OrderLine.last
    assert_equal @order, line.order
    assert_equal 0, line.tax_rate  # GCs are tax-exempt
  end

  test "POST /orders/:id/gift_certificates fails with invalid amount" do
    assert_no_difference "GiftCertificate.count" do
      post order_gift_certificates_path(@order), params: {
        gift_certificate: { initial_amount: "0" }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  test "GET /gift_certificates/lookup returns found for active gc" do
    gc = gift_certificates(:active_gc)
    get gift_certificate_lookup_path, params: { code: gc.code }
    assert_response :success
    json = response.parsed_body
    assert json["found"]
    assert_equal gc.code, json["code"]
    assert_equal gc.remaining_balance.to_f, json["balance"]
  end

  test "GET /gift_certificates/lookup returns not found for exhausted gc" do
    gc = gift_certificates(:exhausted_gc)
    get gift_certificate_lookup_path, params: { code: gc.code }
    assert_response :success
    json = response.parsed_body
    assert_not json["found"]
  end

  test "GET /gift_certificates/lookup returns not found for unknown code" do
    get gift_certificate_lookup_path, params: { code: "GC-NOTEXIST" }
    assert_response :success
    json = response.parsed_body
    assert_not json["found"]
  end

  test "POST creates gc with no tax even when customer has tax code" do
    tax_code = tax_codes(:one)
    customer = customers(:acme_corp)
    customer.update!(tax_code: tax_code) if customer.respond_to?(:tax_code=)

    @order.update!(customer: customer)

    post order_gift_certificates_path(@order), params: {
      gift_certificate: { initial_amount: "100.00" }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    line = OrderLine.where(order: @order, sellable_type: "GiftCertificate").last
    assert_not_nil line
    assert_equal 0, line.tax_rate
  end

  test "requires authentication" do
    delete session_path
    get new_order_gift_certificate_path(@order)
    assert_redirected_to new_session_path
  end
end
