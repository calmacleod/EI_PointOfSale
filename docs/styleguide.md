# UI Styling Guide

EI Point of Sale is an Inertia application rendered by Svelte 5. New UI belongs in Svelte components, not Rails templates.

## Authoritative files

- `app/javascript/design-system/tokens/` defines color, typography, spacing, and shell tokens.
- `app/javascript/design-system/components.css` defines reusable component classes.
- `app/javascript/entrypoints/application.css` contains application-specific compositions.
- `app/javascript/layouts/AppLayout.svelte` owns the application shell and navigation.
- `app/javascript/pages/components/` contains reusable screens and controls.

## Conventions

- Use semantic design tokens instead of literal colors or one-off spacing values.
- Reuse the existing `k-*`, `c-*`, `p-*`, `f-*`, `t-*`, and `ui-*` component classes before adding a new pattern.
- Use Inertia `Link` and `router` APIs for application navigation and mutations.
- Use native Svelte event handlers and state; do not add DOM-controller frameworks or server-rendered UI fragments.
- Keep server-owned filtering and pagination contracts in `Ui::PagePresenter` and `FilterConfig`.
- Preserve keyboard operation, visible focus, meaningful labels, and compact retail-friendly layouts.

## Themes

The application supports `light`, `dark`, and `dim` through `data-theme` on `<html>`. Font scaling uses `data-font-size`. Accent colors are exposed through `--color-accent` and related semantic variables.

Never hardcode a color where an existing semantic token describes the role.

## Page structure

- `page.svelte` selects the screen family from the presenter `view` prop.
- `AppLayout.svelte` provides the shared rail, command bar, status bar, connection state, and notification toast.
- Resource CRUD screens use `ResourceIndex`, `ResourceForm`, and `ResourceShow`.
- Operational workflows use dedicated components or an explicit `SpecialPage` view.

When adding a route, update the presenter contract and add controller coverage for the resulting Inertia props.
