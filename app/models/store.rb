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

  # ── Validations ────────────────────────────────────────────────────
  validates :name, presence: true
  validates :accent_color, inclusion: { in: ACCENT_COLOR_NAMES }

  # ── Instance methods ───────────────────────────────────────────────

  # Formatted full address for display (e.g. receipts, headers).
  def address
    [ address_line1, address_line2, city, province, postal_code, country ].compact_blank.join(", ")
  end

  # Returns the colour definition hash for the current accent_color.
  def accent_palette
    ACCENT_COLORS.fetch(accent_color, ACCENT_COLORS["teal"])
  end

  class << self
    def current
      first || create!(name: "Store")
    end
  end
end
