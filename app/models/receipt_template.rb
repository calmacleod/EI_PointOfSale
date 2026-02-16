# frozen_string_literal: true

class ReceiptTemplate < ApplicationRecord
  audited

  # Standard thermal printer paper widths and their approximate character counts
  PAPER_WIDTHS = {
    58 => { label: "58 mm (narrow)", chars: 32 },
    80 => { label: "80 mm (standard)", chars: 48 }
  }.freeze

  PAPER_WIDTH_OPTIONS = PAPER_WIDTHS.keys.freeze

  # ── Validations ────────────────────────────────────────────────────
  validates :name, presence: true
  validates :paper_width_mm, presence: true, inclusion: { in: PAPER_WIDTH_OPTIONS }
  validates :chars_per_line, presence: true, numericality: { greater_than: 0 }
  validate :only_one_active_template

  # ── Callbacks ──────────────────────────────────────────────────────
  before_validation :set_chars_per_line, if: :paper_width_mm_changed?

  # ── Scopes ─────────────────────────────────────────────────────────
  scope :active, -> { where(active: true) }

  # ── Class methods ──────────────────────────────────────────────────

  def self.current
    active.first
  end

  # ── Instance methods ───────────────────────────────────────────────

  # Returns an array of strings representing each line of the receipt.
  # Pass a Store instance to populate store info.
  def formatted_preview(store: nil)
    store ||= Store.current
    lines = []
    width = chars_per_line || 48

    if show_store_name && store.name.present?
      lines.concat(center_wrap(store.name.upcase, width))
    end

    if show_store_address && store.address.present?
      lines.concat(center_wrap(store.address, width))
    end

    if show_store_phone && store.phone.present?
      lines << center_text("Tel: #{store.phone}", width)
    end

    if show_store_email && store.email.present?
      lines << center_text(store.email, width)
    end

    lines << separator(width) if lines.any?

    if header_text.present?
      header_text.each_line do |line|
        lines.concat(center_wrap(line.chomp, width))
      end
      lines << separator(width)
    end

    if show_date_time
      lines << left_right("Date: #{Time.current.strftime('%Y-%m-%d')}", Time.current.strftime("%H:%M"), width)
    end

    if show_cashier_name
      lines << left_right("Cashier:", "Staff Name", width)
    end

    lines << separator(width) if show_date_time || show_cashier_name

    # Placeholder for future order line items
    lines << ""
    lines << center_text("[ Order items will appear here ]", width)
    lines << ""

    lines << separator(width)
    lines << left_right("Subtotal:", "$0.00", width)
    lines << left_right("Tax:", "$0.00", width)
    lines << left_right("TOTAL:", "$0.00", width)
    lines << separator(width)

    if footer_text.present?
      lines << ""
      footer_text.each_line do |line|
        lines.concat(center_wrap(line.chomp, width))
      end
    end

    lines
  end

  # Deactivate all other templates when this one becomes active.
  def activate!
    transaction do
      self.class.where.not(id: id).update_all(active: false)
      update!(active: true)
    end
  end

  private

    def set_chars_per_line
      info = PAPER_WIDTHS[paper_width_mm]
      self.chars_per_line = info[:chars] if info
    end

    def only_one_active_template
      return unless active?
      return unless self.class.active.where.not(id: id).exists?

      errors.add(:active, "only one template can be active at a time")
    end

    # ── Formatting helpers ─────────────────────────────────────────────

    def center_text(text, width)
      text.truncate(width).center(width)
    end

    def center_wrap(text, width)
      return [ "".center(width) ] if text.blank?

      text.scan(/.{1,#{width}}/).map { |chunk| chunk.center(width) }
    end

    def left_right(left, right, width)
      gap = width - left.length - right.length
      gap = 1 if gap < 1
      "#{left}#{' ' * gap}#{right}"
    end

    def separator(width)
      "=" * width
    end
end
