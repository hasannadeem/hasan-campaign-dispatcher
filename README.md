# Campaign Dispatcher

A proof-of-concept for automating customer review-request collection. Create a
campaign, add a list of recipients, dispatch it, and watch each recipient's
delivery status update in real time — no page refresh.

Sends are simulated (a short random delay per recipient) so the app runs without
a real SMS/email provider.

## Stack

- Ruby 3.2 / Rails 7.2
- PostgreSQL
- Sidekiq + Redis (background dispatch)
- Hotwire — Turbo Streams + Turbo Frames (real-time UI), broadcast over Action Cable
- Tailwind CSS
- RSpec + Capybara

## Getting started

### Prerequisites

- Ruby 3.2.x
- PostgreSQL running locally
- Redis running locally (`redis-server`)

### Setup

```bash
bundle install
bin/rails db:prepare   # create, migrate, seed
```

### Running

Everything (web server, Tailwind watcher, Sidekiq) is wired into `Procfile.dev`:

```bash
bin/dev
```

Then open http://localhost:3000.

Prefer separate terminals? Run them by hand:

```bash
bin/rails server
bin/rails tailwindcss:watch
bundle exec sidekiq -C config/sidekiq.yml
```

The Sidekiq dashboard is mounted at http://localhost:3000/sidekiq. It's open in
development, but is protected with HTTP Basic auth whenever both env vars are set
(recommended in production, since the dashboard exposes recipient emails and can
retry/kill jobs):

```bash
export SIDEKIQ_WEB_USER=admin
export SIDEKIQ_WEB_PASSWORD=change-me
```

Jobs run on weighted queues (`dispatch` is prioritized over the per-recipient
`delivery` fan-out) configured in `config/sidekiq.yml`.

### Tests

```bash
bundle exec rspec
```

The system spec drives a headless Chrome (Selenium Manager fetches the driver
automatically). It needs only PostgreSQL — not Redis — because the test
environment uses the in-process `async` Action Cable adapter and runs the job on
the `async` ActiveJob adapter (so the browser subscribes before the broadcasts
fire). It also relies on database_cleaner's **truncation** strategy for system
specs so the Capybara server thread can see committed rows and `after_*_commit`
callbacks actually fire. Run `bin/rails tailwindcss:build` first (CI and
`bin/setup` do this) so the layout's compiled stylesheet is present.

## How it works

1. Creating a campaign accepts a `Name, email` line per recipient from a
   textarea, parsed by the `RecipientParser` PORO into `Recipient` records.
   Splitting is on the first comma; a line with no comma is treated as a bare
   email, with the name defaulting to the address's local part.
2. **Start dispatch** enqueues `DispatchCampaignJob`. The job flips the campaign
   to `processing`, walks its queued recipients (simulating a send with a 1–3s
   delay each), and marks the campaign `completed` at the end.
3. The campaign show page subscribes once with `turbo_stream_from @campaign`, and
   two kinds of targets ride that one stream:
   - **Recipient rows** broadcast themselves from the model: a
     `Recipient#after_update_commit` replaces the recipient's own `<li>`.
   - **Aggregate progress** is broadcast from the job into the
     `campaign_progress` `<turbo-frame>` (the status badge, the "Sent 5 of 10"
     counter, and the progress bar) after each recipient and once at completion.

   So a row owns its own state, while progress — derived from *sibling* records —
   is owned by the orchestrating job, and each updates independently without a
   refresh.

## Architectural notes

- **Status is modeled as enums** (`Campaign`: pending/processing/completed,
  `Recipient`: queued/sent/failed) backed by integer columns, with a composite
  index on `(campaign_id, status)` for the per-status counts. A `recipients_count`
  counter cache keeps the dashboard list free of N+1 count queries.
- **Broadcasts are split by ownership.** A recipient row is the recipient's own
  concern, so it broadcasts from a model `after_update_commit`. Aggregate
  progress is derived from *sibling* records, so it is the orchestrating job's
  concern and broadcasts from `DispatchCampaignJob` — the recipient's own commit
  is the wrong home for a cross-record rollup. The spec calls for exactly this
  Turbo Streams (rows) / Turbo Frame (progress) split.
- **Failure handling**: the simulated send occasionally rejects a recipient, and
  any exception during a send is rescued, logged, and recorded as `failed` for
  that recipient. One bad recipient never aborts the rest of the campaign.
- **Stimulus is intentionally absent.** Turbo Streams cover every live update
  here, so reaching for custom JavaScript would only add moving parts.
- **Cross-process broadcasting**: because Sidekiq runs in a separate process
  from Puma, Action Cable uses the Redis adapter in development (the default
  `async` adapter can't deliver across processes).

## Trade-offs (6-hour scope)

- Recipient entry is a textarea rather than dynamic nested forms — faster to
  build and friendlier for pasting a real list.
- The "send" is simulated with `sleep`; there's no real provider, retry/backoff
  policy, or rate limiting.
- No authentication, pagination, or campaign editing/deletion.

## Future improvements

The next ~40 hours of work (the automation engine, pause/retry, real sending,
reporting, auth, scale, and UI polish) are laid out in [FUTURE_PLAN.md](FUTURE_PLAN.md).
