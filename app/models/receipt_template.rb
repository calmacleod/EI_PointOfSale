# frozen_string_literal: true

class ReceiptTemplate < ApplicationRecord
  audited

  # Standard thermal printer paper widths and their approximate character counts
  PAPER_WIDTHS = {
    58 => { label: "58 mm (narrow)", chars: 32 },
    80 => { label: "80 mm (standard)", chars: 48 }
  }.freeze

  PAPER_WIDTH_OPTIONS = PAPER_WIDTHS.keys.freeze

  # Ordered list of all draggable receipt sections.
  # Footer text is excluded — it always renders after the totals/payments block.
  SECTIONS = %w[logo store_name store_address store_phone store_email header_text date_time cashier_name].freeze

  SECTION_LABELS = {
    "logo"          => "Logo",
    "store_name"    => "Store Name",
    "store_address" => "Store Address",
    "store_phone"   => "Store Phone",
    "store_email"   => "Store Email",
    "header_text"   => "Header Text",
    "date_time"     => "Date & Time",
    "cashier_name"  => "Cashier Name"
  }.freeze

  # ── Validations ────────────────────────────────────────────────────
  validates :name, presence: true
  validates :paper_width_mm, presence: true, inclusion: { in: PAPER_WIDTH_OPTIONS }
  validates :chars_per_line, presence: true, numericality: { greater_than: 0 }
  validate :only_one_active_template
  validate :valid_section_order

  # ── Callbacks ──────────────────────────────────────────────────────
  before_validation :set_chars_per_line, if: :paper_width_mm_changed?

  # ── Scopes ─────────────────────────────────────────────────────────
  scope :active, -> { where(active: true) }

  # ── Class methods ──────────────────────────────────────────────────

  def self.current
    active.first
  end

  # ── Instance methods ───────────────────────────────────────────────

  # Returns the sections in their configured order, falling back to the default.
  def ordered_sections
    (section_order.presence || SECTIONS).then do |order|
      # Ensure any sections not yet in the stored order are appended at the end
      order | SECTIONS
    end
  end

  # Returns an array of strings representing each line of the receipt.
  # Pass a Store instance to populate store info.
  # Whether the logo should be displayed in the receipt preview.
  # This is handled as an <img> element in the HTML preview, not as text.
  # This method provides only the text portion of the receipt.
  def formatted_preview(store: nil)
    store ||= Store.current
    lines = []
    width = chars_per_line || 48

    header_section_lines = []

    ordered_sections.each do |section|
      section_lines = render_preview_section(section, store, width)
      header_section_lines.concat(section_lines) if section_lines.any?
    end

    lines.concat(header_section_lines)
    lines << separator(width) if lines.any?

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

  # Accept a JSON string from form hidden fields in addition to arrays.
  def section_order=(value)
    super(value.is_a?(String) ? (JSON.parse(value) rescue []) : value)
  end

  private

    # Renders a single named section for the text preview.
    # Returns an array of lines (may be empty if the section is toggled off or has no content).
    def render_preview_section(section, store, width)
      case section
      when "logo"
        [] # Handled as <img> in HTML preview; no text representation
      when "store_name"
        return [] unless show_store_name && store.name.present?
        center_wrap(store.name.upcase, width)
      when "store_address"
        return [] unless show_store_address
        lines = []
        store.receipt_address_lines.each { |l| lines.concat(center_wrap(l, width)) }
        lines
      when "store_phone"
        return [] unless show_store_phone && store.phone.present?
        [ center_text("Tel: #{store.phone}", width) ]
      when "store_email"
        return [] unless show_store_email && store.email.present?
        [ center_text(store.email, width) ]
      when "header_text"
        return [] unless header_text.present?
        lines = []
        header_text.each_line { |l| lines.concat(center_wrap(l.chomp, width)) }
        lines << separator(width)
        lines
      when "date_time"
        return [] unless show_date_time
        [ left_right("Date: #{Time.current.strftime('%Y-%m-%d')}", Time.current.strftime("%H:%M"), width) ]
      when "cashier_name"
        return [] unless show_cashier_name
        [ left_right("Cashier:", "Staff Name", width) ]
      else
        []
      end
    end

    def set_chars_per_line
      info = PAPER_WIDTHS[paper_width_mm]
      self.chars_per_line = info[:chars] if info
    end

    def only_one_active_template
      return unless active?
      return unless self.class.active.where.not(id: id).exists?

      errors.add(:active, "only one template can be active at a time")
    end

    def valid_section_order
      return if section_order.blank?

      invalid = section_order - SECTIONS
      return if invalid.empty?

      errors.add(:section_order, "contains unknown sections: #{invalid.join(', ')}")
    end

    # ── Formatting helpers ─────────────────────────────────────────────

    def center_text(text, width)
      text.truncate(width).center(width)
    end

    def center_wrap(text, width)
      return [ "".center(width) ] if text.blank?

      words = text.split(/\s+/)
      lines = []
      current_line = +""

      words.each do |word|
        if word.length > width
          # Flush the accumulated line before hard-splitting an overlong word
          unless current_line.empty?
            lines << current_line.center(width)
            current_line = +""
          end
          word.scan(/.{1,#{width}}/).each { |chunk| lines << chunk.center(width) }
        elsif current_line.empty?
          current_line = word.dup
        elsif (current_line.length + 1 + word.length) <= width
          current_line << " " << word
        else
          lines << current_line.center(width)
          current_line = word.dup
        end
      end

      lines << current_line.center(width) unless current_line.empty?
      lines.presence || [ "".center(width) ]
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
