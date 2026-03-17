# frozen_string_literal: true

module DataTableHelper
  # Renders all table rows into a single SafeBuffer, bypassing per-row partial
  # overhead. Precomputes static <td> opening tags (once per request) so the hot
  # loop avoids repeated string allocation and ERB binding creation.
  def render_table_rows(records, column_renderers, actions_renderer)
    # Build raw (pre-trusted) td open strings — col.key is a symbol from app
    # code, never user input, so no HTML escaping is needed.
    td_opens = column_renderers.map { |col, _| %(<td class="whitespace-nowrap px-3 py-1.5 text-sm text-body" data-column="#{col.key}">) }
    actions_td = %(<td class="px-3 py-1.5 text-right text-sm" data-column="actions">)

    buf = ActiveSupport::SafeBuffer.new
    records.each do |record|
      buf.safe_concat("<tr>")
      column_renderers.each_with_index do |(_, renderer), i|
        buf.safe_concat(td_opens[i])
        buf << renderer.call(record).to_s if renderer
        buf.safe_concat("</td>")
      end
      buf.safe_concat(actions_td)
      buf << actions_renderer.call(record).to_s if actions_renderer
      buf.safe_concat("</td></tr>")
    end
    buf
  end

  # Builder for the data table partial. Collects row/cell definitions
  # from the block and renders them into the table.
  class DataTableBuilder
    attr_reader :rows

    def initialize(records, view_context)
      @records = records
      @view = view_context
      @rows = []
      @cell_renderers = {}
    end

    # Define a cell renderer for a column key.
    # Usage: table.cell(:code) { |record| link_to record.code, ... }
    def cell(key, &block)
      @cell_renderers[key.to_sym] = block
    end

    # Returns the renderer proc for a key, or nil. Use to precompute renderers
    # before iterating rows so the hash is only looked up once per column.
    def renderer_for(key)
      @cell_renderers[key.to_sym]
    end

    def render_cell(key, record)
      renderer = @cell_renderers[key.to_sym]
      return "" unless renderer

      renderer.call(record).to_s
    end

    def cell_defined?(key)
      @cell_renderers.key?(key.to_sym)
    end
  end
end
