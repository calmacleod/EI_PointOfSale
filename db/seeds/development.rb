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

# ── Store Tasks ───────────────────────────────────────────────────
puts "Seeding store tasks..."

unless StoreTask.exists?
  admin = User.find_by!(email_address: "admin@example.com")
  alice = User.find_by(email_address: "alice@example.com")
  bob   = User.find_by(email_address: "bob@example.com")
  charlie = User.find_by(email_address: "charlie@example.com")

  StoreTask.create!(
    title: "Restock card sleeves display",
    body: "Dragon Shield sleeves are almost sold out on the floor. Restock from the back room — check red, blue, and black.",
    status: :not_started,
    assigned_to: alice,
    due_date: 2.days.from_now.to_date
  )

  StoreTask.create!(
    title: "Clean front display case",
    body: "Fingerprints on the glass from the weekend rush. Give it a good wipe with the glass cleaner.",
    status: :not_started,
    assigned_to: bob,
    due_date: Date.current
  )

  StoreTask.create!(
    title: "Update price tags for hockey cards",
    body: "2024 Upper Deck Series 1 packs went up to $5.49. Replace all shelf tags in the hockey aisle.",
    status: :in_progress,
    assigned_to: alice,
    due_date: 1.day.from_now.to_date
  )

  StoreTask.create!(
    title: "Fix cash drawer sticking",
    body: "The cash drawer has been sticking when opening. Try cleaning the rails or call for a repair if that doesn't work.",
    status: :blocked,
    assigned_to: admin,
    due_date: 1.day.ago.to_date
  )

  StoreTask.create!(
    title: "Order new shopping bags",
    body: "We're almost out of both small and large branded bags. Place an order with the supplier — at least 500 of each.",
    status: :not_started,
    assigned_to: charlie,
    due_date: 3.days.ago.to_date
  )

  StoreTask.create!(
    title: "Inventory count — trading cards section",
    body: "Quarterly count for all TCG products: MTG, Pokémon, and Upper Deck. Use the inventory sheet on the clipboard behind the counter.",
    status: :not_started,
    assigned_to: nil,
    due_date: 5.days.from_now.to_date
  )

  StoreTask.create!(
    title: "Set up weekend sale signage",
    body: "Print and hang the 15% off comics promotion signs. Place one at the entrance, one in the comics aisle, and one at the register.",
    status: :done,
    assigned_to: bob,
    due_date: 2.days.ago.to_date
  )

  StoreTask.create!(
    title: "Replace burned-out light in aisle 2",
    body: "The fluorescent tube above the dice and miniatures section is flickering. Replacements are in the storage closet.",
    status: :not_started,
    assigned_to: alice,
    due_date: 4.days.from_now.to_date
  )

  StoreTask.create!(
    title: "Reorganize back room shelving",
    body: "The back room is getting cluttered after recent shipments. Sort by category: TCG, comics, sports, and novelties. Label each shelf.",
    status: :in_progress,
    assigned_to: charlie,
    due_date: 1.week.from_now.to_date
  )

  StoreTask.create!(
    title: "Call Diamond Comics about late shipment",
    body: "Last week's comic shipment still hasn't arrived. Call Diamond and get a tracking number. Reference order #DC-2026-0847.",
    status: :not_started,
    assigned_to: admin,
    due_date: 2.days.ago.to_date
  )

  puts "  Created #{StoreTask.count} store tasks"
end

# ── Orders ────────────────────────────────────────────────────────────
puts "Seeding orders..."

unless Order.exists?
  admin = User.find_by!(email_address: "admin@example.com")
  alice = User.find_by(email_address: "alice@example.com") || admin
  bob   = User.find_by(email_address: "bob@example.com") || admin

  # Products & Services for orders
  sleeves_red   = Product.find_by(code: "DS-MAT-RED")
  hockey_cards  = Product.find_by(code: "UD-2024-001")
  dice_set      = Product.find_by(code: "DND-DICE-PREM")
  mtg_booster   = Product.find_by(code: "MTG-DOM-BOX")
  pokemon_etb   = Product.find_by(code: "PKM-SV-ETB")
  playmat       = Product.find_by(code: "PLAYMAT-GENERIC")
  puck          = Product.find_by(code: "NHL-PUCK-001")
  comic         = Product.find_by(code: "ASM-001-REPRINT")
  refill_svc    = Service.find_by(code: "SVC-REFILL-SM")
  sleeve_svc    = Service.find_by(code: "SVC-SLEEVE")

  jane     = Customer.find_by(member_number: "100002")
  sarah    = Customer.find_by(member_number: "100004")
  acme     = Customer.find_by(member_number: "100001")

  # Update Jane Doe to have the status indian tax exemption (for demo)
  exempt_tax = TaxCode.find_by(code: "EXEMPT_STATUS_INDIAN")
  if jane && exempt_tax
    jane.update!(tax_code: exempt_tax, status_card_number: "1234-5678-90")
    puts "  Updated Jane Doe with status card and exempt tax code"
  end

  # ── Completed order #1: Cash payment with change ────────────────────
  order1 = Order.create!(created_by: admin, status: :draft)
  OrderEvent.create!(order: order1, event_type: "created", actor: admin, created_at: 2.days.ago)

  if sleeves_red
    line = order1.order_lines.build(quantity: 2)
    line.snapshot_from_sellable!(sleeves_red)
    line.position = 1
    line.save!
  end

  if hockey_cards
    line = order1.order_lines.build(quantity: 5)
    line.snapshot_from_sellable!(hockey_cards)
    line.position = 2
    line.save!
  end

  Orders::CalculateTotals.call(order1)

  order1.order_payments.create!(
    payment_method: :cash,
    amount: order1.total,
    amount_tendered: 60.00,
    change_given: (60.00 - order1.total).round(2),
    received_by: admin
  )
  OrderEvent.create!(order: order1, event_type: "payment_added", actor: admin, data: { method: "Cash", amount: order1.total.to_s }, created_at: 2.days.ago)

  order1.update!(status: :completed, completed_at: 2.days.ago)
  OrderEvent.create!(order: order1, event_type: "completed", actor: admin, data: { total: order1.total.to_s }, created_at: 2.days.ago)
  puts "  Created completed order #{order1.number} (cash with change)"

  # ── Completed order #2: Debit payment, with a customer ──────────────
  order2 = Order.create!(created_by: alice, status: :draft, customer: sarah)
  OrderEvent.create!(order: order2, event_type: "created", actor: alice, created_at: 1.day.ago)

  if dice_set
    line = order2.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(dice_set)
    line.position = 1
    line.save!
  end

  if playmat
    line = order2.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(playmat)
    line.position = 2
    line.save!
  end

  if refill_svc
    line = order2.order_lines.build(quantity: 2)
    line.snapshot_from_sellable!(refill_svc)
    line.position = 3
    line.save!
  end

  Orders::CalculateTotals.call(order2)

  order2.order_payments.create!(
    payment_method: :debit,
    amount: order2.total,
    received_by: alice,
    reference: "****4521"
  )
  OrderEvent.create!(order: order2, event_type: "payment_added", actor: alice, data: { method: "Debit", amount: order2.total.to_s }, created_at: 1.day.ago)

  order2.update!(status: :completed, completed_at: 1.day.ago)
  OrderEvent.create!(order: order2, event_type: "completed", actor: alice, data: { total: order2.total.to_s }, created_at: 1.day.ago)
  puts "  Created completed order #{order2.number} (debit, customer: #{sarah&.name})"

  # ── Completed order #3: Customer with tax code override (Jane Doe — exempt) ──
  order3 = Order.create!(created_by: bob, status: :draft, customer: jane)
  OrderEvent.create!(order: order3, event_type: "created", actor: bob, created_at: 1.day.ago)
  OrderEvent.create!(order: order3, event_type: "customer_assigned", actor: bob, data: { customer_name: jane&.name }, created_at: 1.day.ago)

  if puck
    line = order3.order_lines.build(quantity: 3)
    line.snapshot_from_sellable!(puck, customer_tax_code: jane&.tax_code)
    line.position = 1
    line.save!
  end

  if comic
    line = order3.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(comic, customer_tax_code: jane&.tax_code)
    line.position = 2
    line.save!
  end

  Orders::CalculateTotals.call(order3)

  order3.order_payments.create!(
    payment_method: :credit,
    amount: order3.total,
    received_by: bob,
    reference: "****9876"
  )
  OrderEvent.create!(order: order3, event_type: "payment_added", actor: bob, data: { method: "Credit", amount: order3.total.to_s }, created_at: 1.day.ago)

  order3.update!(status: :completed, completed_at: 1.day.ago, tax_exempt_number: jane&.status_card_number)
  OrderEvent.create!(order: order3, event_type: "completed", actor: bob, data: { total: order3.total.to_s }, created_at: 1.day.ago)
  puts "  Created completed order #{order3.number} (tax exempt customer: #{jane&.name})"

  # ── Completed order #4: With discount, multiple payment methods ─────
  order4 = Order.create!(created_by: admin, status: :draft, customer: acme)
  OrderEvent.create!(order: order4, event_type: "created", actor: admin, created_at: 6.hours.ago)

  if mtg_booster
    line = order4.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(mtg_booster)
    line.position = 1
    line.save!
  end

  if pokemon_etb
    line = order4.order_lines.build(quantity: 2)
    line.snapshot_from_sellable!(pokemon_etb)
    line.position = 2
    line.save!
  end

  if sleeve_svc
    line = order4.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(sleeve_svc)
    line.position = 3
    line.save!
  end

  # Apply a 10% employee discount
  discount = order4.order_discounts.create!(
    name: "Employee Discount",
    discount_type: :percentage,
    value: 10,
    scope: :all_items,
    applied_by: admin
  )
  OrderEvent.create!(order: order4, event_type: "discount_applied", actor: admin, data: { name: "Employee Discount", value: "10%" }, created_at: 6.hours.ago)

  Orders::CalculateTotals.call(order4)

  # Split payment: gift certificate + debit
  gift_amount = 50.00
  remaining = order4.total - gift_amount

  order4.order_payments.create!(
    payment_method: :gift_certificate,
    amount: gift_amount,
    received_by: admin,
    reference: "GC-2026-0042"
  )
  order4.order_payments.create!(
    payment_method: :debit,
    amount: remaining,
    received_by: admin,
    reference: "****1234"
  )

  order4.update!(status: :completed, completed_at: 6.hours.ago)
  OrderEvent.create!(order: order4, event_type: "completed", actor: admin, data: { total: order4.total.to_s }, created_at: 6.hours.ago)
  puts "  Created completed order #{order4.number} (discount + split payment)"

  # ── Held order ──────────────────────────────────────────────────────
  order5 = Order.create!(created_by: alice, status: :draft)
  OrderEvent.create!(order: order5, event_type: "created", actor: alice, created_at: 3.hours.ago)

  if sleeves_red
    line = order5.order_lines.build(quantity: 4)
    line.snapshot_from_sellable!(sleeves_red)
    line.position = 1
    line.save!
  end

  if dice_set
    line = order5.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(dice_set)
    line.position = 2
    line.save!
  end

  Orders::CalculateTotals.call(order5)
  order5.update!(status: :held, held_at: 3.hours.ago)
  OrderEvent.create!(order: order5, event_type: "held", actor: alice, created_at: 3.hours.ago)
  puts "  Created held order #{order5.number}"

  # ── Draft order (in progress) ──────────────────────────────────────
  order6 = Order.create!(created_by: bob, status: :draft)
  OrderEvent.create!(order: order6, event_type: "created", actor: bob, created_at: 30.minutes.ago)

  if hockey_cards
    line = order6.order_lines.build(quantity: 3)
    line.snapshot_from_sellable!(hockey_cards)
    line.position = 1
    line.save!
  end

  Orders::CalculateTotals.call(order6)
  puts "  Created draft order #{order6.number}"

  # ── Refunded order ─────────────────────────────────────────────────
  order7 = Order.create!(created_by: admin, status: :draft)
  OrderEvent.create!(order: order7, event_type: "created", actor: admin, created_at: 3.days.ago)

  if playmat
    line = order7.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(playmat)
    line.position = 1
    line.save!
  end

  if puck
    line = order7.order_lines.build(quantity: 2)
    line.snapshot_from_sellable!(puck)
    line.position = 2
    line.save!
  end

  Orders::CalculateTotals.call(order7)

  order7.order_payments.create!(
    payment_method: :cash,
    amount: order7.total,
    amount_tendered: 60.00,
    change_given: (60.00 - order7.total).round(2),
    received_by: admin
  )

  order7.update!(status: :completed, completed_at: 3.days.ago)
  OrderEvent.create!(order: order7, event_type: "completed", actor: admin, data: { total: order7.total.to_s }, created_at: 3.days.ago)

  # Process a full refund
  refund = Refund.create!(
    order: order7,
    refund_type: :full,
    reason: "Customer changed their mind",
    total: order7.total,
    processed_by: admin
  )

  order7.order_lines.each do |ol|
    refund.refund_lines.create!(
      order_line: ol,
      quantity: ol.quantity,
      amount: ol.line_total,
      restock: ol.sellable_type == "Product"
    )
  end

  order7.update_column(:status, Order.statuses[:refunded])
  OrderEvent.create!(order: order7, event_type: "refund_processed", actor: admin, data: { refund_number: refund.refund_number, total: refund.total.to_s }, created_at: 2.days.ago)
  puts "  Created refunded order #{order7.number}"

  puts "  Created #{Order.count} orders total"
end

# ── Discounts ──────────────────────────────────────────────────────────
puts "Seeding discounts..."

unless Discount.exists?
  # 1. Card Sleeve Deal — $1 off per pack on all Dragon Shield products
  sleeve_deal = Discount.create!(
    name: "Card Sleeve Deal",
    description: "$1.00 off every pack of Dragon Shield card sleeves.",
    discount_type: :fixed_per_item,
    value: 1.00,
    active: true,
    applies_to_all: false
  )
  %w[DS-MAT-RED DS-MAT-BLU DS-MAT-GRN DS-MAT-BLK].each do |code|
    product = Product.find_by(code: code)
    sleeve_deal.discount_items.create!(discountable: product) if product
  end
  puts "  Created \"#{sleeve_deal.name}\" (fixed per item, #{sleeve_deal.discount_items.count} products)"

  # 2. TCG Booster Promo — 5% off booster boxes and trainer boxes
  booster_promo = Discount.create!(
    name: "TCG Booster Promo",
    description: "5% off all booster boxes and Elite Trainer Boxes.",
    discount_type: :percentage,
    value: 5.00,
    active: true,
    applies_to_all: false
  )
  %w[MTG-DOM-BOX PKM-SV-ETB].each do |code|
    product = Product.find_by(code: code)
    booster_promo.discount_items.create!(discountable: product) if product
  end
  puts "  Created \"#{booster_promo.name}\" (5%, #{booster_promo.discount_items.count} products)"

  # 3. Staff Discount — 10% off everything, inactive by default (activate as needed)
  Discount.create!(
    name: "Staff Discount",
    description: "10% off all products and services for staff purchases. Activate when processing a staff sale.",
    discount_type: :percentage,
    value: 10.00,
    active: false,
    applies_to_all: true
  )
  puts "  Created \"Staff Discount\" (10% all items, inactive)"

  puts "  Created #{Discount.count} discounts total"
end
