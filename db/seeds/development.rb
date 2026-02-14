require "bcrypt"

include Sprig::Helpers

sprig [ TaxCode, Supplier, Category, User ]
sprig [ Product, ProductVariant, Service ]

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
