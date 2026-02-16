require "bcrypt"

include Sprig::Helpers

sprig [ TaxCode, Supplier, Category, User ]
sprig [ Product, Service ]
sprig [ Customer ]

# Categorizations (polymorphic - easier in Ruby)
product_category_map = {
  "Dragon Shield Matte Sleeves - Red" => %w[Card Sleeves TCG],
  "Dragon Shield Matte Sleeves - Blue" => %w[Card Sleeves TCG],
  "Dragon Shield Matte Sleeves - Green" => %w[Card Sleeves TCG],
  "Dragon Shield Matte Sleeves - Black" => %w[Card Sleeves TCG],
  "2024 Upper Deck Series 1 Base Pack" => %w[Trading Cards],
  "Amazing Spider-Man #1 Reprint" => %w[Comics],
  "NHL Team Puck - Maple Leafs" => %w[NHL Novelties],
  "MTG Dominaria United Booster Box" => %w[TCG],
  "Pokemon Scarlet & Violet Elite Trainer Box" => %w[TCG],
  "D&D Premium Dice Set" => %w[Novelties]
}

product_category_map.each do |product_name, category_names|
  product = Product.find_by(name: product_name)
  next unless product

  category_names.each do |cat_name|
    category = Category.find_by(name: cat_name)
    next unless category

    product.categories << category unless product.categories.include?(category)
  end
end

# Services -> Services category
services_category = Category.find_by!(name: "Services")
Service.find_each do |service|
  service.categories << services_category unless service.categories.include?(services_category)
end

# ── Seed images ─────────────────────────────────────────────────────
# Attach product images from db/seeds/images/ (free Pexels photos).
# Skips if product already has images (safe to re-run).

images_dir = Rails.root.join("db/seeds/images")

product_images = {
  "UD-2024-001"     => "hockey_cards.jpg",
  "DS-MAT-RED"      => "card_sleeves_red.jpg",
  "DS-MAT-BLU"      => "card_sleeves_red.jpg",
  "DS-MAT-GRN"      => "card_sleeves_red.jpg",
  "DS-MAT-BLK"      => "card_sleeves_red.jpg",
  "ASM-001-REPRINT" => "comic_books.jpg",
  "NHL-PUCK-001"    => "hockey_puck.jpg"
}

product_images.each do |code, filename|
  product = Product.find_by(code: code)
  next unless product
  next if product.images.attached?

  path = images_dir.join(filename)
  next unless File.exist?(path)

  product.images.attach(
    io: File.open(path),
    filename: filename,
    content_type: "image/jpeg"
  )
  puts "  Attached #{filename} to product #{code}"
end

# Attach a store image
store = Store.first
if store && !store.images.attached?
  store_image = images_dir.join("gaming_equipment.jpg")
  if File.exist?(store_image)
    store.images.attach(
      io: File.open(store_image),
      filename: "store_photo.jpg",
      content_type: "image/jpeg"
    )
    puts "  Attached store photo to #{store.name}"
  end
end

# Generate audit trail data (run as admin so audits are attributed)
admin = User.find_by!(email_address: "admin@example.com")
Audited.audit_class.as_user(admin) do
  # Product updates
  Product.find_by(code: "DS-MAT-RED")&.update!(selling_price: 15.99, stock_level: 20)
  Product.find_by(code: "DS-MAT-RED")&.update!(stock_level: 22)
  Product.find_by(code: "UD-2024-001")&.update!(selling_price: 5.49)
  Product.find_by(code: "MTG-DOM-BOX")&.update!(name: "MTG Dominaria United Draft Booster Box")

  # Service updates
  Service.find_by(code: "SVC-REFILL-SM")&.update!(price: 14.99)
  Service.find_by(code: "SVC-SLEEVE")&.update!(description: "We sleeve your cards professionally (per 100)")

  # User updates
  User.find_by(email_address: "alice@example.com")&.update!(name: "Alice Johnson", notes: "Primary contact for orders")
  User.find_by(email_address: "bob@example.com")&.update!(name: "Bob Smith")

  # Tax code update
  TaxCode.find_by(code: "HST")&.update!(notes: "Combined federal and provincial tax for Ontario")

  # Supplier update
  Supplier.find_by(name: "Diamond Comics Distribution")&.update!(name: "Diamond Comics & Collectibles")
end

# ── Receipt Templates ──────────────────────────────────────────────
puts "Seeding receipt templates..."

unless ReceiptTemplate.exists?
  ReceiptTemplate.create!(
    name: "Standard 80mm",
    paper_width_mm: 80,
    show_store_name: true,
    show_store_address: true,
    show_store_phone: true,
    show_store_email: false,
    show_logo: true,
    header_text: "Welcome! Thanks for visiting.",
    footer_text: "Thank you for your purchase!\nReturns accepted within 30 days with receipt.\nHave a great day!",
    show_date_time: true,
    show_cashier_name: true,
    active: true
  )
  puts "  Created Standard 80mm receipt template (active)"

  ReceiptTemplate.create!(
    name: "Compact 58mm",
    paper_width_mm: 58,
    show_store_name: true,
    show_store_address: false,
    show_store_phone: true,
    show_store_email: false,
    show_logo: false,
    header_text: nil,
    footer_text: "Thank you!",
    show_date_time: true,
    show_cashier_name: false,
    active: false
  )
  puts "  Created Compact 58mm receipt template"

  ReceiptTemplate.create!(
    name: "Detailed 80mm",
    paper_width_mm: 80,
    show_store_name: true,
    show_store_address: true,
    show_store_phone: true,
    show_store_email: true,
    show_logo: true,
    header_text: "Your favourite hobby & collectibles shop!",
    footer_text: "Returns within 14 days with receipt.\nExchanges within 30 days.\nThank you for shopping with us!",
    show_date_time: true,
    show_cashier_name: true,
    active: false
  )
  puts "  Created Detailed 80mm receipt template"
end

# ── Cash Drawer Sessions ──────────────────────────────────────────
puts "Seeding cash drawer sessions..."

unless CashDrawerSession.exists?
  admin = User.find_by!(email_address: "admin@example.com")
  alice = User.find_by(email_address: "alice@example.com") || admin

  # Closed session from 3 days ago (exact match)
  CashDrawerSession.create!(
    opened_by: admin,
    closed_by: alice,
    opened_at: 3.days.ago.change(hour: 9, min: 0),
    closed_at: 3.days.ago.change(hour: 17, min: 30),
    opening_counts: { "25c" => 40, "$1" => 30, "$2" => 20, "$5" => 10, "$10" => 5, "$20" => 10 },
    opening_total_cents: 33_000,
    closing_counts: { "25c" => 35, "$1" => 28, "$2" => 22, "$5" => 12, "$10" => 4, "$20" => 11 },
    closing_total_cents: 33_000,
    notes: "Balanced perfectly. Quiet Monday."
  )
  puts "  Created closed session (3 days ago, balanced)"

  # Closed session from 2 days ago (over by $2.50)
  CashDrawerSession.create!(
    opened_by: alice,
    closed_by: admin,
    opened_at: 2.days.ago.change(hour: 8, min: 45),
    closed_at: 2.days.ago.change(hour: 18, min: 15),
    opening_counts: { "25c" => 40, "$1" => 25, "$2" => 15, "$5" => 8, "$10" => 6, "$20" => 8 },
    opening_total_cents: 28_500,
    closing_counts: { "25c" => 52, "$1" => 30, "$2" => 18, "$5" => 6, "$10" => 5, "$20" => 9 },
    closing_total_cents: 28_750,
    notes: "Over by $2.50. Possible miscounted change."
  )
  puts "  Created closed session (2 days ago, +$2.50)"

  # Closed session from yesterday (short by $5.00)
  CashDrawerSession.create!(
    opened_by: admin,
    closed_by: alice,
    opened_at: 1.day.ago.change(hour: 9, min: 15),
    closed_at: 1.day.ago.change(hour: 17, min: 0),
    opening_counts: {
      "5c" => 20, "10c" => 20, "25c" => 40,
      "$1" => 20, "$2" => 15, "$5" => 10,
      "$10" => 5, "$20" => 10, "$1_roll" => 1
    },
    opening_total_cents: 33_800,
    closing_counts: {
      "5c" => 15, "10c" => 18, "25c" => 35,
      "$1" => 22, "$2" => 14, "$5" => 8,
      "$10" => 6, "$20" => 9, "$1_roll" => 1
    },
    closing_total_cents: 33_300,
    notes: "Short $5.00. Will investigate tomorrow."
  )
  puts "  Created closed session (yesterday, -$5.00)"

  # Currently open session (today)
  CashDrawerSession.create!(
    opened_by: admin,
    opened_at: Time.current.change(hour: 9, min: 0),
    opening_counts: {
      "5c" => 20, "10c" => 20, "25c" => 40,
      "$1" => 25, "$2" => 15, "$5" => 10,
      "$10" => 5, "$20" => 10,
      "5c_roll" => 2, "25c_roll" => 1
    },
    opening_total_cents: 33_400
  )
  puts "  Created open session (today)"
end
