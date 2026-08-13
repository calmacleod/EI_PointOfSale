---
name: ei-point-of-sale-design
description: Use this skill to generate well-branded interfaces and assets for EI Point of Sale, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit screens for a dense staff-facing retail operations console.
user-invocable: true
---

Read the readme.md file within this skill, and explore the other available files.

This is an operator console, not a web admin panel: dark chrome (rail, command bar, status
bar) framing white data surfaces, edge-to-edge panels divided by hairlines instead of
floating cards, 26px table rows, monospace for machine data, and visible keyboard hints.
Read readme.md before designing anything — the "Structure" and "Rules of thumb" sections
carry the decisions that make output look like this product rather than a generic
dashboard.

If creating visual artifacts (slides, mocks, throwaway prototypes), copy assets out and
build static HTML that links `styles.css`, composing from the `c-` / `p-` / `t-` / `k-`
class layer and `--color-*` / `--chrome-*` tokens rather than inventing new CSS. If
working on production code, copy assets and read the rules here to become an expert in
designing with this system.

Start from `ui_kits/point_of_sale/` for full-screen layouts and
`components/*/*.card.html` for individual patterns.

If the user invokes this skill without any other guidance, ask them what they want to
build or design, ask some questions, and act as an expert designer who outputs HTML
artifacts _or_ production code, depending on the need.
