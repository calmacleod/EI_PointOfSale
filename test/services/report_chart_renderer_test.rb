# frozen_string_literal: true

require "test_helper"

class ReportChartRendererTest < ActiveSupport::TestCase
  PNG_DATA_URL = "data:image/png;base64,#{Base64.strict_encode64(DUMMY_PNG)}"

  setup do
    @original_chart_js_source = ReportChartRenderer.instance_variable_get(:@chart_js_source)
    ReportChartRenderer.instance_variable_set(:@chart_js_source, "window.Chart = function() {};")
  end

  teardown do
    ReportChartRenderer.instance_variable_set(:@chart_js_source, @original_chart_js_source)
  end

  FakePage = Struct.new(:html, :visited_url) do
    def go_to(url)
      self.visited_url = url
      self.html = File.read(url.delete_prefix("file://"))
    end

    def evaluate(script)
      case script
      when "window.__chartRendered === true"
        true
      when "document.getElementById('chart').toDataURL('image/png')"
        PNG_DATA_URL
      end
    end
  end

  FakeBrowser = Struct.new(:page, :quit_called, keyword_init: true) do
    def create_page
      page
    end

    def quit
      self.quit_called = true
    end
  end

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

  def render_with_fake_browser(chart_data, chart_type:)
    fake_browser = FakeBrowser.new(page: FakePage.new, quit_called: false)

    Ferrum::Browser.stub(:new, fake_browser) do
      png = ReportChartRenderer.render(chart_data, chart_type: chart_type)
      [ png, fake_browser ]
    end
  end

  test "renders a bar chart as PNG binary" do
    png, browser = render_with_fake_browser(sample_bar_chart_data, chart_type: "bar")

    assert png.present?
    assert_kind_of String, png
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
    assert browser.quit_called
  end

  test "renders a line chart as PNG binary" do
    png, = render_with_fake_browser(sample_line_chart_data, chart_type: "line")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  test "renders a pie chart as PNG binary" do
    png, = render_with_fake_browser(sample_pie_chart_data, chart_type: "pie")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  test "defaults to bar chart for unknown chart type" do
    png, browser = render_with_fake_browser(sample_bar_chart_data, chart_type: "unknown")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
    assert_includes browser.page.html, 'const chartType = "bar";'
  end

  test "handles empty datasets gracefully" do
    empty_data = { labels: %w[A B C], datasets: [] }
    png, = render_with_fake_browser(empty_data, chart_type: "bar")

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
    png, browser = render_with_fake_browser(string_keyed, chart_type: "bar")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
    assert_includes browser.page.html, '"labels":["A","B","C"]'
  end

  test "renders chart with many data points" do
    many_labels = (1..30).map { |i| "2026-01-#{i.to_s.rjust(2, '0')}" }
    data = {
      labels: many_labels,
      datasets: [ { label: "Counts", data: many_labels.map { rand(10) } } ]
    }
    png, = render_with_fake_browser(data, chart_type: "bar")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
  end

  def sample_stacked_line_chart_data
    {
      labels: %w[Jan 19 Jan 20 Jan 21 Jan 22 Jan 23],
      datasets: [
        {
          label: "Order Total (Net)",
          data: [ 500, 600, 450, 700, 550 ],
          backgroundColor: "rgba(16, 185, 129, 0.3)",
          borderColor: "rgba(16, 185, 129, 1)",
          stack: "combined"
        },
        {
          label: "Discount Amount",
          data: [ 50, 75, 30, 90, 60 ],
          backgroundColor: "rgba(239, 68, 68, 0.3)",
          borderColor: "rgba(239, 68, 68, 1)",
          stack: "combined"
        }
      ]
    }
  end

  test "renders stacked line chart with stack property" do
    png, browser = render_with_fake_browser(sample_stacked_line_chart_data, chart_type: "line")

    assert png.present?
    assert png.start_with?("\x89PNG".b), "Expected PNG file signature"
    assert_includes browser.page.html, "const stacked = true;"
  end
end
