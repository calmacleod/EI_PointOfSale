# EI Point of Sale — Design System

A staff-facing retail operations workspace: sales, payments, discounts, refunds, gift
certificates, cash-drawer reconciliation, inventory, products, services, customers,
tasks, reports, and administration. Everything a counter needs during a shift, in one
window.

## The problem this system solves

The existing UI is a competent **web admin panel**: a 224px labelled sidebar, a title
block on every page, rounded cards floating on grey with gaps and shadows, 49px table
rows. Nothing about it is broken. But it reads as amateur for a specific, diagnosable
reason — it looks like a website, and the work it supports is not browsing. A cashier
with a queue is not reading a page; they are driving an instrument.

So this is not a reskin. The visual model changed:

**Dark chrome, white data.** The rail, command bar, and status bar are near-black in
every theme. They are the machine. The content area is white — it is the record. You
never have to work out which region you are looking at, and the frame stops competing
with the data for attention.

**Space is earned, not given.** There is no page gutter and no gap between panels.
Regions are separated by a single 1px rule. Everything that was a floating card is now a
panel that fills its region edge to edge.

**Colour reports facts.** Teal means "this is the action". Every other colour in the
interface is telling you something true about a record — this order is held, this stock
is negative, this task is overdue.

**Keys are first-class.** A till is driven by F-keys. The UI says so out loud: key caps
on the actions themselves, and a persistent status bar listing the contextual ones.

The measurable result: **26px rows instead of 49px** (~24 rows visible instead of ~5),
**180px of width returned** by the icon rail, and one 34px command bar in place of a 60px
per-page title block.

---

## Sources

Built by reading the production application directly — not from screenshots.

- **Codebase:** `EI_PointOfSale` (local folder attached to this project).
  Ruby 4.0.1 / Rails 8.1, Inertia + Svelte 5, Vite, Tailwind 4, PostgreSQL.
- **Structure and behaviour:** `app/views/**` (ERB, the mature surface) and
  `app/javascript/pages/components/*.svelte`. Key files: `shared/_sidebar`,
  `shared/_data_table`, `shared/_filter_bar`, `dashboard/index`, `products/index`,
  `products/_form`, `sessions/new`, `RegisterPage.svelte`, `ResourceIndex.svelte`.
- **Rules encoded in helpers:** `app/helpers/ui_helper.rb` (`ui_button_class`,
  `order_status_chip`) and `app/helpers/application_helper.rb` (`status_chip`,
  `accent_color_style_tag` — the store-configurable accent).
- **Retained from the old token layer:** Inter with character variants
  `cv02 cv03 cv04 cv11`, teal `#0d9488` / `#2dd4bf`, the three-theme model
  (light / dark / dim), the `data-font-size` accessibility bump, and the semantic
  intent behind success / warning / danger.
- **Fonts:** `app/assets/fonts/Inter-*.ttf` → `assets/fonts/`.
- **Mark:** `public/icon.svg` → `assets/icon.svg`.

### The drift to fix first

The app runs two frontends with two token sets. ERB declares `--color-*` with teal
`#0d9488` and 8px radii; Svelte declares `--primary` with teal `#0f766e` and 10.4px
radii. That is the direct mechanical cause of the page-to-page inconsistency. Both are
superseded here — port both layers onto `tokens/` and the divergence cannot recur.

---

## Visual foundations

**Stance.** An operator console. The reference points are airline check-in terminals,
warehouse scanners, and trading desks — not admin dashboards. Crisp, flat, dense, fast.
Nothing decorative earns its place.

**Two colour worlds.** `--chrome-*` for the frame (constant across themes) and
`--color-*` for data surfaces (themed). A component belongs to one or the other and uses
its buttons accordingly: `.c-btn` on chrome, `.k-btn` on data. They are not
interchangeable.

**Two border weights.** `--color-border` for row rules and panel edges;
`--color-border-strong` for column heads and control outlines. That single distinction
is what gives a dense table readable structure with no shading at all.

**Type is split by origin.** Inter for language — labels, prose, buttons, names.
Monospace with tabular figures for anything a machine produced: barcodes, SKUs, order
numbers, quantities, money, timestamps, variance. This is not a style choice. Reading
`5011921914760` against `5011921914777` in proportional type means counting digits;
in tabular mono the difference is positional and instant.

**The scale is short.** 10px uppercase micro-labels, 11px meta, 12px data, 13px UI,
15px strong, then two mono readouts at 22px and 34px. Nothing between 15 and 22 exists,
because the interface has data type and readout type and no editorial middle.

**Radii are near zero.** 2px on controls, 3px on keys, 4px on modals. Rounding is a large
part of what made the old UI read as a web page. Only the count badge is a pill.

**Elevation is for floating things only.** Panels have no shadow — ever. Modals, popovers,
and toasts have one, because they genuinely float.

**State has three carriers, one meaning.** A 3px **stripe** on a row's left edge, a 10px
uppercase **tag** where a label is needed, and a **wash** on notice bars. The bordered
pill is gone: it cost 20px of row height and read as decoration.

**Motion is 90ms, colour only.** Nothing moves, scales, lifts, or fades in. Between a
barcode scan and the line item appearing, an animation is a delay.

**Focus is always visible** — a 1px accent border plus a 1px accent ring. Staff tab
through the tender panel constantly; keyboard operation is a primary path, not a
fallback.

**Imagery: there is none,** and that is correct. The only images in the product are
user-uploaded product photos. Placeholders are striped boxes with a mono caption. No
stock photography, no illustration, no hero art.

---

## Structure

```
┌────┬──────────────────────────────────────────────┐
│    │ command bar · 34px                           │
│rail├──────────────────────────────────────────────┤
│ 44 │ content — panels, no gutter, hairline rules  │
│    ├──────────────────────────────────────────────┤
│    │ status bar · 26px                            │
└────┴──────────────────────────────────────────────┘
```

**Rail — 44px, icons only.** Labels arrive as hover tooltips; that is what buys back the
180px. The active item is a 2px teal bar on the rail edge — teal never fills a nav item.
Counts ride the icon via `data-count`, toned `warn` or `bad`.

**Command bar — 34px.** Replaces the per-page title block entirely: breadcrumb path,
live drawer state, global search with `⌘K`, and the one primary action. Pages do not
introduce their own titles; the path *is* the title.

**Content.** A `.p-split` grid of `.p-region` panels. Each panel has a 28px
`.p-head` (10px uppercase title, count, right-aligned actions), a body, and optionally a
`.p-foot`. Panels never nest and never float.

**Status bar — 26px, always present.** Connection and sync, drawer and float, current
user and role, and the contextual key hints right-aligned.

**Reserved keys.** `F2` new sale · `F3` held · `F4–F7` tender methods · `F8` hold ·
`F12` complete · `Esc` cancel · `⌘K` search · `⌘S` save · `/` filter. A screen may add
keys; it may never reassign these.

**Density.** 26px rows by default, 32px with `data-density="roomy"` on any ancestor for
touch-heavy terminals. Cells are `nowrap`; the one column allowed to break opts in with
`class="wrap"`. Tables scroll — wrap in `.t-wrap` and give the table a real pixel
`min-width` so overflow actually engages.

**Touch.** Anything tapped during a sale is 44px (`--control-key`): tender keys, jump
keys, the sign-in submit. Desk-only chrome may go to 22px.

---

## Content fundamentals

**Voice: direct, second person, no filler.** "Payment is complete. This will finalize the
order and update inventory." Never "Oops!", never "Great job!", never an exclamation mark.

**Casing: sentence case,** except the 10px micro-labels (column headers, panel titles,
field labels, state tags), which are uppercase with `--tracking-label`.

**Buttons name the action.** "Take payment", "Void order", "Commit restock". Never
"Submit", "OK", or "Continue" when a real verb exists.

**Say the number.** The command bar reads "52,817 items · 321 below reorder · 14
suppliers", not "Manage your products". Scope beats purpose every time.

**Destructive copy states the consequence, quantified, before the confirmation.**
"4 line items, 1 payment of $100.00, and the staff discount will be reversed. The drawer
will be adjusted. This cannot be undone." The safe option is first and is what `Esc`
triggers.

**Errors are specific and actionable.** "Reorder level must be zero or greater", not
"Invalid input". Validation appears twice: a notice bar at the top of the form, and an
inline message under the offending field.

**Empty states say what to do next,** in two lines: the emptiness, then one instruction.

**Em dash for absent values** — never blank, never "N/A", never "null".

**Numbers are always formatted** — currency through the formatter, thousands separated,
dates as "Aug 12, 2026 9:14am", relative time under a day.

**No emoji.** Anywhere.

---

## Iconography

**Lucide, outline, stroke 1.6, fill none, always `currentColor`.** 17px in the rail,
13–14px in controls, never larger. The Svelte layer already imports `@lucide/svelte`;
the ERB layer hand-inlines Heroicons-ish paths — standardise on Lucide and delete the
inline copies.

In the rail an icon is the only label (the text is a hover tooltip). Everywhere else
every icon is paired with words. No emoji, no filled sets, no second family, no
hand-drawn SVG. The `×` on remove buttons is set in the UI font — the one sanctioned
exception.

**Brand mark.** The repository ships only a favicon. No logo artwork exists and none has
been invented: wherever a mark is needed the product sets "EI" in Inter Bold on the
accent — 28px in the rail, 32px on sign-in. Supply real artwork and it drops into
`assets/`.

---

## Themes

Three, set with `data-theme` on `<html>`: **light**, **dark**, **dim** (dark, one step
lighter, for bright counters). Chrome does not change between them — only data surfaces
re-value. Because every colour is a token, a correct screen themes for free; if a screen
breaks in dark mode it hard-coded a hex.

`data-font-size="large|xlarge"` bumps the root to 17px or 18px. Layouts must survive it,
which is why widths are fluid and heights are `min-height`.

---

## Index

| Path | What it is |
| --- | --- |
| `styles.css` | The entry point. Link this one file. |
| `tokens/colors.css` | Chrome, data surfaces, accent, five states, all three themes |
| `tokens/typography.css` | Inter `@font-face`, the Inter/mono split, scale, weights |
| `tokens/layout.css` | Frame geometry, spacing, radii, control heights, density, motion |
| `tokens/base.css` | Element resets, link colours, `.data` / `.num` / `.neg` |
| `tokens/sidebar.css` | Compatibility aliases onto `--chrome-*` for migration |
| `components.css` | `c-` chrome · `p-` panels · `t-` tables · `k-` controls · `s-` state · `f-` filters · `m-` metrics · `r-` readouts · `n-` notices |
| `guidelines/*.card.html` | Colour, type, structure, density, keyboard, brand specimens |
| `components/*/*.card.html` | Chrome · controls · panels · tables · feedback |
| `ui_kits/point_of_sale/` | Six console screens + index with a before/after table |
| `assets/` | Favicon and Inter font files |
| `SKILL.md` | Agent-skill wrapper |

**Screens:** Dashboard · Register · Products · Product detail & edit · Reports · Sign in.

---

## Rules of thumb

1. Never write a hex. If the colour you want is not a token, the design is wrong.
2. Chrome or data — pick one per component, and use `.c-btn` or `.k-btn` accordingly.
3. No card. Use a panel: no radius, no shadow, no gap, fills its region.
4. One primary action per screen, and it lives in the command bar.
5. Machine data is mono and tabular. Language is Inter.
6. State is a stripe, a tag, and a wash — never a bordered pill, never its own column.
7. Labels are always visible. Placeholders are examples, not labels.
8. Tables scroll: `.t-wrap` + a pixel `min-width`, `class="wrap"` on the one breaking
   column. They never shrink, stack, or auto-hide columns.
9. Every significant action shows its key cap, and the status bar repeats the contextual
   ones.
10. Confirm destructive and financial actions with the consequence quantified. Never
    confirm reversible work.
11. Inline SVGs get their size from `components.css`, not from the caller.
12. Test light, dark, and dim before calling anything finished.
