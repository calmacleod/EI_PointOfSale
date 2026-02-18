# frozen_string_literal: true

require "ferrum"
require "tempfile"
require "net/http"

# Renders a chart image (PNG binary) from a report's chart data using
# headless Chrome and the real Chart.js library — producing output
# identical to the in-browser chart.
#
# Accepts the same Chart.js-format data that the front-end uses:
#   { labels: [...], datasets: [{ label: "...", data: [...] }] }
#
# Usage:
#   png_data = ReportChartRenderer.render(chart_data, chart_type: "bar")
#
class ReportChartRenderer
  CHART_JS_URL  = "https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"
  CHART_JS_CACHE = Rails.root.join("tmp", "chart.umd.min.js")
  CANVAS_WIDTH  = 900
  CANVAS_HEIGHT = 400

  class << self
    def render(chart_data, chart_type: "bar")
      chart_data = chart_data.deep_symbolize_keys
      html = build_html(chart_data, chart_type)

      tmpfile = Tempfile.new([ "chart", ".html" ])
      tmpfile.write(html)
      tmpfile.close

      browser = Ferrum::Browser.new(
        headless: "new",
        window_size: [ CANVAS_WIDTH + 40, CANVAS_HEIGHT + 40 ],
        timeout: 15,
        process_timeout: 10
      )

      begin
        page = browser.create_page
        page.go_to("file://#{tmpfile.path}")

        # Poll until Chart.js signals rendering is complete
        wait_for_chart(page)

        # Extract the canvas as a base64 PNG
        data_url = page.evaluate("document.getElementById('chart').toDataURL('image/png')")
        base64   = data_url.sub(%r{\Adata:image/png;base64,}, "")
        Base64.decode64(base64)
      ensure
        browser.quit
        tmpfile.unlink
      end
    end

    private

      def wait_for_chart(page, timeout: 10)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

        loop do
          rendered = page.evaluate("window.__chartRendered === true")
          return if rendered

          if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
            error = page.evaluate("window.__chartError") rescue nil
            raise "Chart rendering timed out after #{timeout}s. JS error: #{error}"
          end

          sleep 0.1
        end
      end

      # Downloads Chart.js once and caches it locally in tmp/
      def chart_js_source
        @chart_js_source ||= begin
          unless CHART_JS_CACHE.exist?
            Rails.logger.info { "[ReportChartRenderer] Downloading Chart.js to #{CHART_JS_CACHE}" }
            uri = URI(CHART_JS_URL)
            js  = Net::HTTP.get(uri)
            FileUtils.mkdir_p(CHART_JS_CACHE.dirname)
            File.write(CHART_JS_CACHE, js)
          end
          File.read(CHART_JS_CACHE)
        end
      end

      def has_stacked_datasets?(chart_data)
        return false unless chart_data[:datasets].is_a?(Array)

        chart_data[:datasets].any? { |dataset| dataset[:stack].present? }
      end

      def build_html(chart_data, chart_type)
        chart_json = chart_data.to_json
        js_source  = chart_js_source
        stacked    = has_stacked_datasets?(chart_data.deep_symbolize_keys)

        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body { background: #ffffff; }
              .container { width: #{CANVAS_WIDTH}px; height: #{CANVAS_HEIGHT}px; }
            </style>
            <script>#{js_source}</script>
          </head>
          <body>
            <div class="container">
              <canvas id="chart" width="#{CANVAS_WIDTH}" height="#{CANVAS_HEIGHT}"></canvas>
            </div>
            <script>
              try {
                const ctx = document.getElementById("chart").getContext("2d");
                const chartData = #{chart_json};
                const chartType = #{chart_type.to_json};
                const stacked = #{stacked.to_json};

                const gridColor = "rgba(0, 0, 0, 0.1)";
                const textColor = "rgba(0, 0, 0, 0.7)";

                new Chart(ctx, {
                  type: chartType,
                  data: chartData,
                  options: {
                    responsive: false,
                    animation: false,
                    plugins: {
                      legend: {
                        display: true,
                        labels: { color: textColor, font: { size: 12 } }
                      }
                    },
                    scales: chartType === "pie" || chartType === "doughnut" ? {} : {
                      x: {
                        ticks: { color: textColor, font: { size: 11 }, maxRotation: 45 },
                        grid: { color: gridColor },
                        stacked: stacked
                      },
                      y: {
                        beginAtZero: true,
                        ticks: { color: textColor, font: { size: 11 }, precision: 0 },
                        grid: { color: gridColor },
                        stacked: stacked
                      }
                    }
                  },
                  plugins: [{
                    id: "renderComplete",
                    afterRender: function() { window.__chartRendered = true; }
                  }]
                });
              } catch(e) {
                window.__chartError = e.message;
                window.__chartRendered = true;
              }
            </script>
          </body>
          </html>
        HTML
      end
  end
end
