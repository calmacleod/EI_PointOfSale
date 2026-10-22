require "test_helper"

module ReportTemplates
  class CustomExportTest < ActiveSupport::TestCase
    test "exports exactly the selected customer columns and excludes discarded customers" do
      customers(:acme_corp).discard
      parameters = CustomExport.normalize_parameters(dataset: "customers", columns: %w[member_number email])
      result = CustomExport.generate(parameters.symbolize_keys)
      assert_equal Customer.kept.count, result[:table].size
      assert result[:table].all? { |row| row.keys == %i[member_number email] }
      refute_includes result[:table].map { |row| row[:email] }, customers(:acme_corp).email
    end

    test "rejects arbitrary datasets, model attributes, and empty selections" do
      [ { dataset: "users" }, { dataset: "customers", columns: [ "password_digest" ] }, { dataset: "sales", columns: [] } ].each do |input|
        parameters = CustomExport.normalize_parameters(input)
        assert CustomExport.parameter_errors(parameters).any?, input.inspect
        assert_raises(ArgumentError) { CustomExport.generate(parameters.symbolize_keys) }
      end
    end

    test "sales dates filter completed sales and exclude held orders" do
      order = orders(:completed_order)
      parameters = CustomExport.normalize_parameters(dataset: "sales", start_date: order.completed_at.to_date.iso8601, end_date: order.completed_at.to_date.iso8601)
      result = CustomExport.generate(parameters.symbolize_keys)
      numbers = result[:table].map { |row| row[:order_number] }
      assert_includes numbers, order.number
      refute_includes numbers, orders(:held_order).number
      parameters["start_date"] = "2000-01-01"
      parameters["end_date"] = "2000-01-02"
      assert_empty CustomExport.generate(parameters.symbolize_keys)[:table]
    end

    test "refund export uses refund date even when original sale is outside range" do
      order = orders(:completed_order)
      order.update_columns(completed_at: 1.year.ago)
      refund = Refund.create!(order: order, processed_by: users(:admin), refund_type: :partial, total: 5)
      parameters = CustomExport.normalize_parameters(dataset: "refunds", start_date: Date.current.iso8601, end_date: Date.current.iso8601)
      result = CustomExport.generate(parameters.symbolize_keys)
      assert_equal [ refund.refund_number ], result[:table].map { |row| row[:refund_number] }
      assert_equal 5.to_d, result[:table].first[:total]
    end

    test "inventory export uses current unit costs and quantities" do
      product = products(:dragon_shield_red)
      parameters = CustomExport.normalize_parameters(dataset: "inventory")
      row = CustomExport.generate(parameters.symbolize_keys)[:table].find { |item| item[:code] == product.code }
      assert_equal product.stock_level, row[:stock]
      assert_equal (product.unit_cost || product.purchase_price).to_d * product.stock_level, row[:cost_value]
      assert_equal Product.kept.count, CustomExport.generate(parameters.symbolize_keys)[:table].size
    end
  end
end
