# frozen_string_literal: true

module ApplicationHelper
  # Generates a <style> tag that overrides the CSS accent custom properties
  # based on the store's configured accent colour.  Returns an empty string
  # when the default (teal) is selected so no extra CSS is injected.
  def accent_color_style_tag
    store = Store.current
    return "".html_safe if store.accent_color == "teal"

    palette = store.accent_palette
    tag.style(<<~CSS.html_safe, nonce: true)
      :root, [data-theme="light"] {
        --color-accent: #{palette[:light]};
        --color-accent-hover: #{palette[:light_hover]};
        --color-accent-quiet: color-mix(in srgb, #{palette[:light]} 12%, var(--color-surface));
      }
      [data-theme="dark"] {
        --color-accent: #{palette[:dark]};
        --color-accent-hover: #{palette[:dark_hover]};
        --color-accent-quiet: color-mix(in srgb, #{palette[:dark]} 20%, var(--color-surface));
      }
      [data-theme="dim"] {
        --color-accent: #{palette[:dark]};
        --color-accent-hover: #{palette[:dark_hover]};
        --color-accent-quiet: color-mix(in srgb, #{palette[:dark]} 20%, var(--color-surface));
      }
    CSS
  end
end
