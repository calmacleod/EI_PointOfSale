# frozen_string_literal: true

module DataTableHelper
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
