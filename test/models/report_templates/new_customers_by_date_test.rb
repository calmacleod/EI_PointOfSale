# frozen_string_literal: true

require "test_helper"

module ReportTemplates
  class NewCustomersByDateTest < ActiveSupport::TestCase
    test "is registered in the template registry" do
      template = ReportTemplate.find("new_customers_by_date")
      assert_equal NewCustomersByDate, template
    end

    test "has required class methods" do
      assert_equal "new_customers_by_date", NewCustomersByDate.key
      assert_equal "New customers by date", NewCustomersByDate.title
      assert NewCustomersByDate.description.present?
      assert_equal "bar", NewCustomersByDate.chart_type
    end

    test "parameters defines start_date and end_date" do
      params = NewCustomersByDate.parameters
      assert_equal 2, params.size
      assert_equal :start_date, params[0][:key]
      assert_equal :end_date, params[1][:key]
      assert_equal :date, params[0][:type]
    end

    test "table_columns defines expected columns" do
      columns = NewCustomersByDate.table_columns
      keys = columns.map { |c| c[:key] }
      assert_includes keys, :name
      assert_includes keys, :member_number
      assert_includes keys, :email
      assert_includes keys, :registered_on
    end

    test "generate returns chart, table, and summary" do
      result = NewCustomersByDate.generate(
        start_date: 1.year.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      assert result[:chart].present?
      assert result[:chart][:labels].is_a?(Array)
      assert result[:chart][:datasets].is_a?(Array)
      assert result[:table].is_a?(Array)
      assert result[:summary].is_a?(Hash)
      assert result[:summary][:total_customers].is_a?(Integer)
    end

    test "generate fills in zero-count days" do
      # Use a date range where we know no customers were created
      result = NewCustomersByDate.generate(
        start_date: "2020-01-01",
        end_date: "2020-01-03"
      )

      assert_equal 3, result[:chart][:labels].size
      assert_equal [ 0, 0, 0 ], result[:chart][:datasets].first[:data]
    end

    test "generate includes fixture customers in date range" do
      # acme_corp has joining_date but created_at is set by fixtures to now
      result = NewCustomersByDate.generate(
        start_date: Date.current.to_s,
        end_date: Date.current.to_s
      )

      # At least the kept fixture customers should appear
      names = result[:table].map { |r| r[:name] }
      assert_includes names, "Acme Corp"
      assert_includes names, "Jane Doe"
    end
  end
end
