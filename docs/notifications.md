# Notifications & Web Push

EI Point of Sale has a two-layer notification system:

1. **In-app notifications** — Real-time toasts and a persistent notification center delivered via Action Cable.
2. **Web Push notifications** — Background notifications delivered through the browser's Push API, even when the app is minimised or the tab is closed.

---

## Architecture Overview

```
Background Job (e.g. GenerateReportJob)
        │
        ▼
   NotifyService.call(...)
        │
        ├── 1. Persist to DB  (if persistent: true)
        ├── 2. Broadcast via Action Cable  →  In-app toast + badge update
        └── 3. Send Web Push              →  OS-level notification
```

All notifications flow through `NotifyService`, which handles persistence, real-time delivery, and push delivery in one call.

---

## Notification Types

| Type | Persistent | Example |
|------|-----------|---------|
| Report ready | Yes | Stored in the notification center; user can click to view the report |
| Database backup complete | No | Toast only; disappears after 5 seconds |
| MinIO backup complete | No | Toast only; disappears after 5 seconds |

**Persistent notifications** are stored in the `notifications` table and appear in the notification bell dropdown. Users can mark them as read, dismiss them individually, or clear all.

**Ephemeral notifications** are broadcast via Action Cable and Web Push but are not stored in the database.

---

## Sending a Notification

Use `NotifyService` from anywhere in the application (jobs, controllers, services):

```ruby
NotifyService.call(
  user: user,              # Required — the recipient
  title: "Report ready",   # Required — shown in toast and push
  body: "Sales Summary has finished generating.",  # Optional
  category: "report",      # Optional — for filtering/styling
  url: "/reports/42",      # Optional — where to navigate on click
  persistent: true         # Default: true — store in notification center
)
```

### Notifying multiple users

```ruby
User.where(type: "Admin").find_each do |admin|
  NotifyService.call(
    user: admin,
    title: "Backup complete",
    body: "Nightly database backup uploaded.",
    category: "backup",
    persistent: false
  )
end
```

---

## Action Cable

Real-time delivery uses `NotificationChannel`, which streams per-user. The channel is authenticated via the existing session cookie in `ApplicationCable::Connection`.

### Cable adapter

In development and production, the app uses **Solid Cable** (database-backed adapter) so that notifications broadcast from Solid Queue worker processes reach the browser's WebSocket connection:

```yaml
# config/cable.yml
development:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

> **Note:** The `async` adapter only works within a single process and will not deliver notifications from background jobs.

### Client-side

The `notifications` Stimulus controller (`app/javascript/controllers/notifications_controller.js`) connects to the channel on page load using `@rails/actioncable` and:

- Renders toast notifications in the top-right corner (auto-dismiss after 5 seconds)
- Increments the unread badge on the notification bell
- Manages the notification dropdown popover (mark read, dismiss, clear all)

---

## Web Push Setup

Web Push uses the [web-push](https://github.com/zaru/webpush) gem with VAPID (Voluntary Application Server Identification) keys.

### 1. Generate VAPID keys (one-time)

```bash
bin/rails runner "keys = WebPush.generate_key; puts \"Public:  #{keys.public_key}\"; puts \"Private: #{keys.private_key}\""
```

### 2. Add keys to environment

Add these to `.env` (development) or your production secrets:

```
VAPID_PUBLIC_KEY=BGlQ1tOt...your_public_key...
VAPID_PRIVATE_KEY=vQgEFdCE...your_private_key...
VAPID_CONTACT=mailto:admin@yourdomain.com
```

The `VAPID_CONTACT` should be a `mailto:` URI that push services can use to contact you if there's an issue.

### 3. User opt-in

Users enable push notifications from **Profile > Push Notifications**. This:

1. Prompts the browser for notification permission
2. Subscribes the browser via `PushManager.subscribe()` with the VAPID public key
3. Sends the subscription endpoint to `POST /push_subscriptions`

Subscriptions are stored in the `push_subscriptions` table, scoped per-user and per-browser. A user can have multiple subscriptions (e.g. desktop + phone).

### 4. Delivery

When `NotifyService` runs, it iterates over the user's push subscriptions and sends a Web Push message to each. If a subscription has expired or been revoked, it is automatically deleted.

### 5. Service Worker

The service worker (`app/views/pwa/service-worker.js`) handles `push` events by showing an OS-level notification, and `notificationclick` events by focusing or opening the relevant page.

---

## UI Components

### Notification bell

- **Desktop:** In the sidebar bottom section, shows a bell icon with an unread count badge. Click opens a popover with recent persistent notifications.
- **Mobile:** In the top header bar, same behaviour.

### Toast notifications

Fixed to the top-right of the viewport (below the mobile header on small screens). Each toast:

- Slides in with a 300ms animation
- Shows the notification title, body, and a bell icon
- Clicking navigates to the notification's `url` (if set)
- Auto-dismisses after 5 seconds
- Can be manually dismissed via the close button

### Notification popover

The dropdown shows up to 20 recent persistent notifications with:

- Unread highlighting (accent background tint)
- Timestamps via `local_time`
- Per-notification dismiss button (appears on hover)
- "Mark all read" button (clears unread state)
- "Clear all" button (deletes all notifications)

---

## Database Tables

### `notifications`

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | references | Recipient |
| `title` | string | Notification title (required) |
| `body` | text | Optional longer description |
| `category` | string | e.g. `"report"`, `"backup"`, `"system"` |
| `url` | string | Link to navigate to on click |
| `persistent` | boolean | Whether it appears in the notification center (default: true) |
| `read_at` | datetime | When the user marked it as read (null = unread) |

### `push_subscriptions`

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | references | Owner |
| `endpoint` | text | Push service URL |
| `p256dh_key` | string | Public encryption key |
| `auth_key` | string | Auth secret |

Unique index on `[user_id, endpoint]`.

---

## Testing

### Manual testing from Rails console

```bash
bin/rails console
```

```ruby
# Send a persistent in-app notification
user = User.first
NotifyService.call(user: user, title: "Test", body: "Hello from the console!", persistent: true)

# Send an ephemeral toast-only notification
NotifyService.call(user: user, title: "Quick toast", persistent: false)
```

### Automated tests

```bash
bin/rails test test/models/notification_test.rb
bin/rails test test/services/notify_service_test.rb
bin/rails test test/controllers/notifications_controller_test.rb
bin/rails test test/controllers/push_subscriptions_controller_test.rb
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Toasts don't appear | Check the browser console for WebSocket errors. Ensure `bin/dev` is running and cable.yml uses `solid_cable`. |
| Push notifications don't appear | Ensure `VAPID_PUBLIC_KEY` and `VAPID_PRIVATE_KEY` are set in `.env`. Check that the user has enabled push in Profile and accepted the browser permission prompt. |
| Notifications from jobs don't arrive | The `async` cable adapter only works within a single process. Switch to `solid_cable` in `config/cable.yml` so job workers can broadcast. |
| "Notification permission denied" | The user previously blocked notifications. They need to reset the permission in browser settings (Site Settings > Notifications). |
| Push subscriptions disappearing | Expired or invalid subscriptions are automatically cleaned up when a push delivery fails. The user can re-enable from Profile. |
