require "bcrypt"

include Sprig::Helpers

sprig [ TaxCode, Supplier, Category, User ]
sprig [ Product, ProductVariant, Service ]
sprig [ Customer ]

# Categorizations (polymorphic - easier in Ruby)
product_category_map = {
  "Dragon Shield Matte Sleeves" => %w[Card Sleeves TCG],
  "2024 Upper Deck Series 1" => %w[Trading Cards],
  "Amazing Spider-Man #1 Reprint" => %w[Comics],
  "NHL Team Puck - Maple Leafs" => %w[NHL Novelties]
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

# Generate audit trail data (run as admin so audits are attributed)
admin = User.find_by!(email_address: "admin@example.com")
Audited.audit_class.as_user(admin) do
  # Product updates
  Product.find_by(name: "Dragon Shield Matte Sleeves")&.update!(product_url: "https://www.dragonshield.com/products")
  Product.find_by(name: "2024 Upper Deck Series 1")&.update!(name: "2024 Upper Deck Series 1 Hockey")
  Product.find_by(name: "MTG Dominaria United Booster Box")&.update!(name: "MTG Dominaria United Draft Booster Box")

  # Service updates
  Service.find_by(code: "SVC-REFILL-SM")&.update!(price: 14.99)
  Service.find_by(code: "SVC-SLEEVE")&.update!(description: "We sleeve your cards professionally (per 100)")

  # User updates
  User.find_by(email_address: "alice@example.com")&.update!(name: "Alice Johnson", notes: "Primary contact for orders")
  User.find_by(email_address: "bob@example.com")&.update!(name: "Bob Smith")

  # Product variant updates
  pv = ProductVariant.find_by(code: "DS-MAT-RED")
  pv&.update!(selling_price: 15.99, stock_level: 20)
  pv&.update!(stock_level: 22)

  ProductVariant.find_by(code: "UD-2024-001")&.update!(selling_price: 5.49)

  # Tax code update
  TaxCode.find_by(code: "HST")&.update!(notes: "Combined federal and provincial tax for Ontario")

  # Supplier update
  Supplier.find_by(name: "Diamond Comics Distribution")&.update!(name: "Diamond Comics & Collectibles")
end
