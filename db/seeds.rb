# Seeds are managed with Sprig.
#
# - Environment entrypoint: `db/seeds/<env>.rb`
# - Data files: `db/seeds/<env>/*.yml` (also supports json/csv)
#
# Usage:
#   bin/rails db:seed
#

begin
  require "sprig"
rescue LoadError
  warn "Sprig is not installed. Run `bundle install`."
  return
end

env_seed = Rails.root.join("db", "seeds", "#{Rails.env}.rb")
load env_seed if env_seed.exist?

puts "Sprig seeded #{Rails.env} data"
