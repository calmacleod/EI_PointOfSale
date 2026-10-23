# frozen_string_literal: true

module Offline
  class CatalogSync
    PAGE_SIZE = 500
    class InvalidCursor < StandardError; end

    def initialize(model, since: nil, page_size: nil, cursor: nil)
      @model = model
      @since = parse_time(since)
      @page_size = page_size.present? ? page_size.to_i.clamp(1, PAGE_SIZE) : nil
      @cursor = cursor
    end

    def call
      return legacy_response unless @page_size || @cursor.present?

      # @type var state: Hash[String, untyped]?
      state = @cursor.present? ? verifier.verified(@cursor, purpose: @model.name) : nil
      raise InvalidCursor if @cursor.present? && !state

      boundary = state ? Time.iso8601(state.fetch("until")) : Time.current
      since = state ? parse_time(state["since"]) : @since
      page_size = state ? state.fetch("page_size") : (@page_size || PAGE_SIZE)
      table = @model.arel_table
      scope = since ? @model.where(table[:updated_at].gteq(since)) : @model.kept
      scope = scope.where(table[:updated_at].lteq(boundary))
      if state
        scope = scope.where("(#{@model.table_name}.updated_at, #{@model.table_name}.id) > (?, ?)", Time.iso8601(state.fetch("updated_at")), state.fetch("id"))
      end
      rows = CatalogSerializer.rows(scope.order(table[:updated_at], table[:id]).limit(page_size + 1))
      more = rows.length > page_size
      rows = rows.first(page_size)
      next_cursor = if more
        verifier.generate({ "until" => boundary.iso8601(6), "since" => since&.iso8601(6),
          "page_size" => page_size, "updated_at" => rows.last.fetch(:updated_at).iso8601(6), "id" => rows.last.fetch(:id) },
          purpose: @model.name, expires_in: 1.hour)
      end

      records, discarded = rows.partition { |row| row[:discarded_at].nil? }
      { @model.table_name => records.map { |row| CatalogSerializer.record(row) },
        deleted_ids: discarded.map { |row| row.fetch(:id) }, synced_at: boundary.iso8601(6), next_cursor: next_cursor }
    end

    private

      def verifier
        Rails.application.message_verifier("offline-catalog-sync")
      end

      def parse_time(value)
        Time.zone.parse(value) if value.present?
      rescue ArgumentError, TypeError
        nil
      end

      # Old cached JS does not understand pages. Keep its complete response until
      # those clients have refreshed; new clients always request bounded pages.
      def legacy_response
        boundary = Time.current
        scope = @model.kept
        scope = scope.where("#{@model.table_name}.updated_at >= ?", @since) if @since
        deleted = @since ? @model.discarded.where("updated_at >= ?", @since).pluck(:id) : []
        { @model.table_name => CatalogSerializer.rows(scope).map { |row| CatalogSerializer.record(row) },
          deleted_ids: deleted, synced_at: boundary.iso8601(6) }
      end
  end
end
