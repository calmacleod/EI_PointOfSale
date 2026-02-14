class EnablePostgresExtensions < ActiveRecord::Migration[8.1]
  def up
    enable_extension "plpgsql" unless connection.extension_enabled?("plpgsql")
    enable_extension "pg_trgm"
  end

  def down
    disable_extension "pg_trgm"
    # plpgsql is not disabled - it is a core PostgreSQL extension
  end
end
