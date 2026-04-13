# frozen_string_literal: true

# Patch PGlite::Result with methods that the Rails PostgreSQL adapter expects
# but that the wasmify-rails pglite adapter doesn't implement.
# These patches only apply in the WASM environment where PGlite is the database.
return unless Rails.env.wasm?

require "active_record/connection_adapters/pglite_adapter"

# PostgreSQL OID::Array#initialize references PG::TextEncoder::Array and
# PG::TextDecoder::Array, which the wasmify-rails pg shim doesn't define.
# Patch the initializer to tolerate missing encoder/decoder constants so
# the type map can be populated without aborting boot.
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class Array
          # Minimal stand-ins used when PG::TextEncoder/TextDecoder are unavailable (PGlite).
          NullEncoder = Struct.new(:name, :delimiter) do
            def encode(value)
              items = value.is_a?(::Array) ? value : [ value ]
              "{#{items.map(&:to_s).join(delimiter || ",")}}"
            end

            def freeze
              self
            end
          end

          NullDecoder = Struct.new(:name, :delimiter) do
            def decode(value)
              value.to_s.delete("{}").split(delimiter || ",")
            end

            def freeze
              self
            end
          end

          def initialize(subtype, delimiter = ",")
            @subtype = subtype
            @delimiter = delimiter
            @pg_encoder = PG::TextEncoder::Array.new(name: "#{type}[]".freeze, delimiter: delimiter).freeze
            @pg_decoder = PG::TextDecoder::Array.new(name: "#{type}[]".freeze, delimiter: delimiter).freeze
          rescue NameError
            @pg_encoder = NullEncoder.new("#{type}[]", delimiter)
            @pg_decoder = NullDecoder.new("#{type}[]", delimiter)
          end
        end
      end
    end
  end
end

# Ruby's C date parser (date__parse) crashes in ruby.wasm with a native
# "memory access out of bounds" fault — an unrecoverable WASM RuntimeError.
# Override Date._parse with a pure-Ruby implementation before any code
# can reach the C extension.  Handles all formats Rails uses internally:
#   ISO 8601 date/datetime, compact migration timestamps, and slash-separated US dates.
require "date"

class Date
  module WasmSafeParse
    def _parse(str, comp = true)
      str = str.to_s.strip
      return {} if str.empty?

      r = {}

      case str
      # Compact timestamp: 20260406151040
      when /\A(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\z/
        r = { year: $1.to_i, mon: $2.to_i, mday: $3.to_i,
              hour: $4.to_i, min: $5.to_i, sec: $6.to_i }

      # ISO 8601 datetime: 2024-01-15T10:30:00.123Z or 2024-01-15 10:30:00+05:30
      when /\A(\d{4})-(\d{1,2})-(\d{1,2})[T ](\d{1,2}):(\d{2}):(\d{2})(\.\d+)?(Z|[+-]\d{2}:?\d{2})?\z/
        r = { year: $1.to_i, mon: $2.to_i, mday: $3.to_i,
              hour: $4.to_i, min: $5.to_i, sec: $6.to_i }
        if $7
          frac = $7[1..]
          r[:sec_fraction] = Rational(frac.to_i, 10**frac.length)
        end
        r[:zone] = $8 if $8

      # ISO 8601 date only: 2024-01-15
      when /\A(\d{4})-(\d{1,2})-(\d{1,2})\z/
        r = { year: $1.to_i, mon: $2.to_i, mday: $3.to_i }

      # US slash date: 01/15/2024
      when /\A(\d{1,2})\/(\d{1,2})\/(\d{4})\z/
        r = { year: $3.to_i, mon: $1.to_i, mday: $2.to_i }
      end

      if comp && r[:year] && r[:year] < 100
        r[:year] += r[:year] >= 69 ? 1900 : 2000
      end

      r
    end
  end

  singleton_class.prepend(WasmSafeParse)
end

# PG::Result#ntuples returns the number of rows in the result set.
# Rails' postgresql/database_statements.rb calls this on every query result.
PGlite::Result.class_eval do
  def ntuples
    @res[:rows].to_a.length
  end
end

# PGlite doesn't support extensions like pg_trgm or pgcrypto.
# Silently ignore enable_extension calls for unavailable extensions so that
# loading db/schema.rb (which calls enable_extension "pg_trgm") doesn't abort boot.
module ActiveRecord
  module ConnectionAdapters
    class PGliteAdapter < PostgreSQLAdapter
      def enable_extension(name, **)
        super
      rescue PG::Error => e
        raise unless e.message.include?("is not available")
        Rails.logger.debug { "[pglite] Skipping unavailable extension: #{name}" }
      end

      def add_index(table_name, column_name, **)
        super
      rescue PG::Error => e
        raise unless e.message.include?("does not exist for access method")
        Rails.logger.debug { "[pglite] Skipping index on #{table_name} (unsupported operator class): #{e.message}" }
      end
    end
  end
end
