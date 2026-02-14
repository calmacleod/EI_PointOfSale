# UI Styling Guide

This document describes the EI Point of Sale UI conventions for developers and AI agents. Use these patterns when creating or modifying views and components.

---

## Theme System

The app supports three themes: **light**, **dark**, and **dim**. Themes are controlled via `data-theme` on `<html>`, set from the user's saved preferences (stored on the User model and editable from the profile page).

### CSS Variables (Semantic Tokens)

Use these CSS custom properties instead of hardcoded colors:

| Token | Purpose |
|-------|---------|
| `--color-page` | Page/body background |
| `--color-surface` | Cards, sidebar, modal backgrounds |
| `--color-border` | Borders, dividers |
| `--color-text` | Primary text (use `text-body` utility) |
| `--color-text-muted` | Secondary text (use `text-muted` utility) |
| `--color-accent` | Primary actions, links, highlights |
| `--color-accent-hover` | Hover state for accent elements |
| `--color-success-bg`, `--color-success-border`, `--color-success-text` | Success/notice flash messages |
| `--color-error-bg`, `--color-error-border`, `--color-error-text` | Error/alert flash messages |

### Using Theme Tokens

**Utility classes:**
- `bg-page`, `bg-surface` — backgrounds
- `text-body`, `text-muted` — text colors
- `border-theme` — borders
- `bg-accent`, `text-accent` — accent styling

**Arbitrary values** (when no utility exists):
- `bg-[var(--color-page)]`
- `text-[var(--color-error-text)]`
- `border-[var(--color-border)]`

### Theme Selector

Users change theme, font size, and sidebar preference from the profile page (Edit profile → Display settings). These are persisted on the User model and applied on each page load.

---

## Font Scaling

Font size is controlled via `data-font-size` on `<html>`:
- `default`: 16px base
- `large`: 18px base
- `xlarge`: 20px base

Tailwind's `rem`-based utilities scale automatically. Prefer:
- `text-base` for body text (scales with root)
- `text-xl`, `text-2xl` for headings
- Avoid fixed `text-sm` for critical content; use `text-base` for readability in retail contexts.

---

## Button Conventions

### Touch Targets

All interactive elements (buttons, primary links) must meet a **minimum 44×44px** touch target:
- Use `min-h-[44px] min-w-[44px]` or `px-4 py-3` (or equivalent padding)
- `py-3` on table cells for tap-friendly rows

### Primary Buttons

```erb
class="inline-flex min-h-[44px] items-center justify-center rounded-lg bg-accent px-4 py-3 text-base font-semibold text-[color:var(--color-page)] shadow-sm hover:bg-[var(--color-accent-hover)] focus:outline-none focus:ring-2 focus:ring-[var(--color-accent)]"
```

### Secondary / Outline Buttons

```erb
class="inline-flex min-h-[44px] items-center justify-center rounded-lg border-theme bg-surface px-4 py-3 text-base font-semibold text-body ring-1 ring-inset hover:bg-[var(--color-border)] focus:outline-none focus:ring-2 focus:ring-[var(--color-accent)]"
```

### Danger Buttons

Use `--color-error-*` tokens or semantic error classes when needed. Prefer theme tokens over hardcoded red.

### Spacing

- Adequate gap between adjacent buttons to avoid misclicks
- Use `gap-2` or `gap-3` for button groups

---

## Color Usage

| Context | Use |
|---------|-----|
| Page background | `bg-page` or `--color-page` |
| Cards, modals, sidebar | `bg-surface` or `--color-surface` |
| Primary actions (submit, nav active) | `bg-accent`, `text-accent` |
| Secondary text, hints | `text-muted` |
| Borders, dividers | `border-theme` or `border-[var(--color-border)]` |
| Success messages | `--color-success-bg`, `--color-success-text` |
| Error messages | `--color-error-bg`, `--color-error-text` |

---

## Layout Patterns

### Sidebar + Main

- Sidebar: `bg-surface`, `border-theme` (right border on desktop)
- Main: `flex-1`, `px-4 py-8 sm:px-6 lg:px-8`
- Content wrapper: `mx-auto w-full max-w-screen-2xl`

### Cards

- `rounded-xl border border-theme bg-surface p-4 shadow-sm`
- Use `divide-y divide-[var(--color-border)]` for sectioned content inside cards

### Tables

- Wrapper: `overflow-x-auto` for horizontal scroll on mobile
- Table: `min-w-full divide-y divide-[var(--color-border)]`
- Header: `bg-[var(--color-border)]/30`
- Cells: `px-4 py-3 text-base text-body` (or `text-muted` for secondary)
- Ensure `min-w` on table so it scrolls instead of squashing on narrow screens

---

## Responsive Rules

### Breakpoints (Tailwind defaults)

- `sm:` 640px
- `md:` 768px
- `lg:` 1024px

### Mobile Sidebar

- Below `lg`: Sidebar is a slide-in drawer. Hamburger button (fixed top-left) toggles it. Overlay dims main content; clicking overlay closes sidebar.
- At `lg`: Sidebar is always visible, in normal flex flow.
- Use `lg:hidden` for hamburger/overlay; `lg:flex` / `lg:static` for sidebar on desktop.

### Tables on Mobile

- Wrap in `overflow-x-auto` so tables scroll horizontally
- Cell padding `py-3` for touch-friendly rows
- Optional: card-style layout for rows at `max-sm:` if table has many columns

### General

- Avoid fixed widths that break on narrow viewports
- Prefer `max-w-full`, `w-full`, `min-w-0`
- Body: `overflow-x-hidden` to prevent horizontal scroll

---

## Page Titles

**Always** use `content_for :title` for new pages:

```erb
<% content_for :title, "Page Name" %>
```

The layout uses: `<%= content_for(:title) || "Ei Point Of Sale" %>`. Missing titles fall back to the app name.

---

## Turbo

- **Turbo Drive** is enabled by default; links use Turbo for SPA-like navigation.
- **Prefetch**: Add `data: { turbo_prefetch: true }` to high-traffic links (sidebar nav, quick actions) so pages load on hover/focus.
- **Morph**: Layout uses `turbo_refreshes_with method: :morph` for minimal DOM updates.
- Avoid `data: { turbo: false }` unless necessary (e.g. file uploads).

---

## Form Inputs

Use theme-aware styles for inputs:

```erb
class="block w-full min-h-[44px] rounded-md border-[var(--color-border)] bg-surface text-body shadow-sm focus:border-[var(--color-accent)] focus:ring-2 focus:ring-[var(--color-accent)]"
```

For placeholders: `placeholder:text-muted` or rely on default contrast.

---

## Quick Reference

| Need | Class / Pattern |
|------|-----------------|
| Page background | `bg-page` |
| Card background | `bg-surface` |
| Primary text | `text-body` |
| Secondary text | `text-muted` |
| Primary button | `bg-accent`, `text-[color:var(--color-page)]`, `min-h-[44px]`, `px-4 py-3` |
| Border | `border-theme` |
| Error message | `bg-[var(--color-error-bg)]`, `text-[var(--color-error-text)]` |
| Success message | `bg-[var(--color-success-bg)]`, `text-[var(--color-success-text)]` |
| Prefetch link | `data: { turbo_prefetch: true }` |
