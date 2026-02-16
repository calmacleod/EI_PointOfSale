# frozen_string_literal: true

require "test_helper"

class ReceiptTemplateTest < ActiveSupport::TestCase
  # ── Validations ────────────────────────────────────────────────────

  test "requires name" do
    template = ReceiptTemplate.new(paper_width_mm: 80, chars_per_line: 48)
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "requires valid paper width" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 42)
    assert_not template.valid?
    assert_includes template.errors[:paper_width_mm], "is not included in the list"
  end

  test "accepts 58mm paper width" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 58, active: false)
    assert template.valid?
    assert_equal 32, template.chars_per_line
  end

  test "accepts 80mm paper width" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 80, active: false)
    assert template.valid?
    assert_equal 48, template.chars_per_line
  end

  test "only one active template allowed" do
    existing = receipt_templates(:standard)
    assert existing.active?

    new_template = ReceiptTemplate.new(name: "Another", paper_width_mm: 80, active: true)
    assert_not new_template.valid?
    assert_includes new_template.errors[:active], "only one template can be active at a time"
  end

  test "valid template" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 80, active: false)
    assert template.valid?
  end

  # ── Callbacks ──────────────────────────────────────────────────────

  test "sets chars_per_line from paper_width_mm" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 58, active: false)
    template.valid?
    assert_equal 32, template.chars_per_line
  end

  test "updates chars_per_line when paper_width changes" do
    template = receipt_templates(:standard)
    assert_equal 48, template.chars_per_line

    template.paper_width_mm = 58
    template.valid?
    assert_equal 32, template.chars_per_line
  end

  # ── Scopes ─────────────────────────────────────────────────────────

  test "active scope returns only active templates" do
    results = ReceiptTemplate.active
    assert results.all?(&:active?)
    assert_equal 1, results.count
  end

  # ── Class methods ──────────────────────────────────────────────────

  test "current returns the active template" do
    current = ReceiptTemplate.current
    assert_not_nil current
    assert current.active?
  end

  # ── formatted_preview ──────────────────────────────────────────────

  test "formatted_preview returns an array of strings" do
    template = receipt_templates(:standard)
    lines = template.formatted_preview
    assert_kind_of Array, lines
    assert lines.all? { |l| l.is_a?(String) }
  end

  test "formatted_preview includes store name when enabled" do
    template = receipt_templates(:standard)
    store = Store.current
    store.update!(name: "Test Store")

    lines = template.formatted_preview(store: store)
    assert lines.any? { |l| l.include?("TEST STORE") }
  end

  test "formatted_preview excludes store name when disabled" do
    template = receipt_templates(:standard)
    template.show_store_name = false
    store = Store.current
    store.update!(name: "Test Store")

    lines = template.formatted_preview(store: store)
    assert_not lines.any? { |l| l.include?("TEST STORE") }
  end

  test "formatted_preview includes header text when present" do
    template = receipt_templates(:standard)
    lines = template.formatted_preview
    assert lines.any? { |l| l.include?("Welcome to our store!") }
  end

  test "formatted_preview includes footer text when present" do
    template = receipt_templates(:standard)
    lines = template.formatted_preview
    assert lines.any? { |l| l.include?("Thank you for shopping with us!") }
  end

  test "formatted_preview includes date line when enabled" do
    template = receipt_templates(:standard)
    lines = template.formatted_preview
    assert lines.any? { |l| l.include?("Date:") }
  end

  test "formatted_preview excludes date line when disabled" do
    template = receipt_templates(:standard)
    template.show_date_time = false
    lines = template.formatted_preview
    assert_not lines.any? { |l| l.include?("Date:") }
  end

  test "formatted_preview lines respect chars_per_line width" do
    template = receipt_templates(:standard)
    lines = template.formatted_preview
    lines.each do |line|
      assert line.length <= template.chars_per_line,
             "Line exceeds #{template.chars_per_line} chars: #{line.inspect} (#{line.length})"
    end
  end

  test "formatted_preview for narrow template respects 32 chars" do
    template = receipt_templates(:narrow)
    lines = template.formatted_preview
    lines.each do |line|
      assert line.length <= 32,
             "Line exceeds 32 chars: #{line.inspect} (#{line.length})"
    end
  end

  # ── center_wrap word-wrapping ─────────────────────────────────────

  test "address wraps at word boundaries instead of mid-word" do
    template = receipt_templates(:narrow) # 32 chars wide
    template.show_store_address = true
    store = Store.current
    store.update!(
      address_line1: "123 Main Street",
      city: "Springfield",
      province: "IL",
      postal_code: "62704",
      country: "United States"
    )

    lines = template.formatted_preview(store: store)
    address_lines = lines.select { |l| l.strip.match?(/Main|Springfield|United/) }

    address_lines.each do |line|
      # Each word in the line should be whole (no split postal codes, city names, etc.)
      words = line.strip.split(/[\s,]+/).reject(&:empty?)
      words.each do |word|
        full_address = store.address
        assert full_address.include?(word),
               "Word '#{word}' appears split from the original address: #{full_address}"
      end
    end
  end

  test "postal code is not split across receipt lines" do
    template = receipt_templates(:narrow) # 32 chars wide
    template.show_store_address = true
    store = Store.current
    store.update!(
      address_line1: "456 Longview Boulevard",
      city: "Charlottetown",
      province: "PE",
      postal_code: "C1A 4N6",
      country: "Canada"
    )

    lines = template.formatted_preview(store: store)

    # Both halves of the postal code "C1A 4N6" must appear on the same line
    postal_line = lines.find { |l| l.include?("C1A") }
    assert_not_nil postal_line, "Postal code should appear in the receipt"
    assert_includes postal_line, "4N6",
                    "Both halves of postal code must be on the same line, got: #{postal_line.inspect}"
  end

  # ── show_logo ─────────────────────────────────────────────────────

  test "show_logo defaults to true" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 80, active: false)
    assert template.show_logo?
  end

  test "show_logo can be set to false" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 80, show_logo: false, active: false)
    assert_not template.show_logo?
  end

  # ── trim_logo ─────────────────────────────────────────────────────

  test "trim_logo defaults to false" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 80, active: false)
    assert_not template.trim_logo?
  end

  test "trim_logo can be set to true" do
    template = ReceiptTemplate.new(name: "Test", paper_width_mm: 80, trim_logo: true, active: false)
    assert template.trim_logo?
  end

  # ── activate! ──────────────────────────────────────────────────────

  test "activate! makes this template active and deactivates others" do
    standard = receipt_templates(:standard)
    narrow = receipt_templates(:narrow)

    assert standard.active?
    assert_not narrow.active?

    narrow.activate!
    assert narrow.reload.active?
    assert_not standard.reload.active?
  end
end
