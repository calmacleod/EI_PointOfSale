# frozen_string_literal: true

require "test_helper"

class ReportChartRendererTest < ActiveSupport::TestCase
  def sample_bar_chart_data
    {
      labels: [ "2026-02-10", "2026-02-11", "2026-02-12", "2026-02-13", "2026-02-14" ],
      datasets: [
        {
          label: "New customers",
          data: [ 3, 7, 2, 5, 4 ],
          backgroundColor: "rgba(59, 130, 246, 0.6)",
          borderColor: "rgba(59, 130, 246, 1)",
          borderWidth: 1
        }
      ]
    }
  end

  def sample_line_chart_data
    {
      labels: %w[Jan Feb Mar Apr May],
      datasets: [
        { label: "Revenue", data: [ 100, 200, 150, 300, 250 ] },
        { label: "Expenses", data: [ 80, 120, 130, 200, 180 ] }
      ]
    }
  end

  def sample_pie_chart_data
    {
      labels: %w[Electronics Clothing Food],
      datasets: [
        { label: "Sales", data: [ 40, 35, 25 ] }
      ]
    }
  end

  test "renders a bar chart as PNG binary" do
    png = ReportChartRenderer.render(sample_bar_chart_data, chart_type: "bar")

    assert png.present?
    assert_kind_of String, png
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  test "renders a line chart as PNG binary" do
    png = ReportChartRenderer.render(sample_line_chart_data, chart_type: "line")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  test "renders a pie chart as PNG binary" do
    png = ReportChartRenderer.render(sample_pie_chart_data, chart_type: "pie")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  test "defaults to bar chart for unknown chart type" do
    png = ReportChartRenderer.render(sample_bar_chart_data, chart_type: "unknown")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  test "handles empty datasets gracefully" do
    empty_data = { labels: %w[A B C], datasets: [] }
    png = ReportChartRenderer.render(empty_data, chart_type: "bar")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  test "handles string-keyed chart data" do
    string_keyed = {
      "labels" => %w[A B C],
      "datasets" => [
        { "label" => "Test", "data" => [ 1, 2, 3 ] }
      ]
    }
    png = ReportChartRenderer.render(string_keyed, chart_type: "bar")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  test "renders chart with many data points" do
    many_labels = (1..30).map { |i| "2026-01-#{i.to_s.rjust(2, '0')}" }
    data = {
      labels: many_labels,
      datasets: [ { label: "Counts", data: many_labels.map { rand(10) } } ]
    }
    png = ReportChartRenderer.render(data, chart_type: "bar")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end
end
