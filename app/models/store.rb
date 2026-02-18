class Store < ApplicationRecord
  audited

  # ── Accent colour palette ──────────────────────────────────────────
  # Each entry maps a human-friendly name to the CSS custom-property
  # values used in light, dark, and dim themes.
  #
  #   light:  accent shown on white/light backgrounds (needs WCAG AA contrast)
  #   dark:   accent shown on dark backgrounds
  #   dim:    accent shown on mid-tone backgrounds (shares dark palette by default)
  #
  ACCENT_COLORS = {
    "teal"    => { label: "Teal",    light: "#0d9488", light_hover: "#0f766e", dark: "#2dd4bf", dark_hover: "#5eead4",
                   swatch: "#0d9488" },
    "blue"    => { label: "Blue",    light: "#2563eb", light_hover: "#1d4ed8", dark: "#60a5fa", dark_hover: "#93c5fd",
                   swatch: "#2563eb" },
    "indigo"  => { label: "Indigo",  light: "#4f46e5", light_hover: "#4338ca", dark: "#818cf8", dark_hover: "#a5b4fc",
                   swatch: "#4f46e5" },
    "emerald" => { label: "Emerald", light: "#059669", light_hover: "#047857", dark: "#34d399", dark_hover: "#6ee7b7",
                   swatch: "#059669" },
    "amber"   => { label: "Amber",   light: "#d97706", light_hover: "#b45309", dark: "#fbbf24", dark_hover: "#fcd34d",
                   swatch: "#d97706" },
    "rose"    => { label: "Rose",    light: "#e11d48", light_hover: "#be123c", dark: "#fb7185", dark_hover: "#fda4af",
                   swatch: "#e11d48" },
    "violet"  => { label: "Violet",  light: "#7c3aed", light_hover: "#6d28d9", dark: "#a78bfa", dark_hover: "#c4b5fd",
                   swatch: "#7c3aed" },
    "slate"   => { label: "Slate",   light: "#475569", light_hover: "#334155", dark: "#94a3b8", dark_hover: "#cbd5e1",
                   swatch: "#475569" }
  }.freeze

  ACCENT_COLOR_NAMES = ACCENT_COLORS.keys.freeze

  # ── Normalizations ─────────────────────────────────────────────────
  normalizes :email, with: ->(e) { e.to_s.strip.downcase.presence }

  # ── Attachments ────────────────────────────────────────────────────
  has_many_attached :images
  has_one_attached :logo

  # ── Validations ────────────────────────────────────────────────────
  validates :name, presence: true
  validates :accent_color, inclusion: { in: ACCENT_COLOR_NAMES }
  validate :logo_must_be_square_image, if: -> { logo.attached? && logo.new_record? }

  # ── Constants ──────────────────────────────────────────────────────

  # Thermal receipt printers typically have a print width in dots.
  # 80mm paper ≈ 384 dots at 203 dpi; 58mm ≈ 384 dots but narrower.
  THERMAL_LOGO_WIDTHS = {
    58 => 192,
    80 => 384
  }.freeze

  # ── Instance methods ───────────────────────────────────────────────

  # Formatted full address as a single string for general display.
  def address
    [ address_line1, address_line2, city, province, postal_code, country ].compact_blank.join(", ")
  end

  # Address split into logical lines for receipt formatting.
  # Groups related fields so postal codes and city names stay intact.
  def receipt_address_lines
    lines = []
    street = [ address_line1, address_line2 ].compact_blank.join(", ")
    lines << street if street.present?
    locale = [ city, province, postal_code ].compact_blank.join(", ")
    lines << locale if locale.present?
    lines << country if country.present?
    lines
  end

  # Returns the colour definition hash for the current accent_color.
  def accent_palette
    ACCENT_COLORS.fetch(accent_color, ACCENT_COLORS["teal"])
  end

  # Returns a resized, square variant of the logo suitable for display
  # in receipt previews. Size is determined by paper width.
  # When trim is true, whitespace borders are stripped via libvips
  # before resizing, reducing wasted paper on thermal printers.
  def logo_for_receipt(paper_width_mm: 80, trim: false)
    return nil unless logo.attached?

    size = THERMAL_LOGO_WIDTHS.fetch(paper_width_mm, 384)

    if trim
      logo.variant(trim_whitespace: true, resize_to_limit: [ size, size ])
    else
      logo.variant(resize_to_limit: [ size, size ])
    end
  end

  # Returns a monochrome (1-bit dithered) variant of the logo optimised
  # for thermal receipt printers. Uses Floyd-Steinberg dithering via
  # libvips for the best halftone quality on thermal paper.
  def thermal_logo(paper_width_mm: 80)
    return nil unless logo.attached?

    size = THERMAL_LOGO_WIDTHS.fetch(paper_width_mm, 384)
    logo.variant(
      resize_to_limit: [ size, size ],
      colourspace: "b-w",
      format: :png
    )
  end

  class << self
    def current
      first || create!(name: "Store")
    end
  end

  private

    def logo_must_be_square_image
      unless logo.content_type.in?(%w[image/png image/jpeg image/gif image/webp])
        errors.add(:logo, "must be a PNG, JPEG, GIF, or WebP image")
        return
      end

      # Try to verify the image is approximately square.
      # If the blob hasn't been analyzed yet, attempt to analyze it.
      # Skip the dimension check if the file isn't available for analysis.
      begin
        logo.blob.analyze unless logo.blob.analyzed?
      rescue ActiveStorage::FileNotFoundError
        return
      end

      metadata = logo.blob.metadata
      width = metadata["width"]
      height = metadata["height"]

      return unless width && height

      ratio = width.to_f / height
      unless ratio.between?(0.9, 1.1)
        errors.add(:logo, "must be square (current ratio is #{width}x#{height})")
      end
    end
end
