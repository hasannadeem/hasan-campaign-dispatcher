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

The Sidekiq dashboard is mounted at http://localhost:3000/sidekiq.

### Tests

```bash
bundle exec rspec
```

The system spec drives a headless Chrome (Selenium Manager fetches the driver
automatically) and needs Redis available.

## How it works

1. Creating a campaign accepts a `Name, contact` line per recipient from a
   textarea, parsed in the controller into `Recipient` records.
2. **Start dispatch** enqueues `DispatchCampaignJob`. The job flips the campaign
   to `processing`, walks its queued recipients (simulating a send with a 1–3s
   delay each), and marks the campaign `completed` at the end.
3. The campaign show page subscribes with `turbo_stream_from @campaign`. As each
   recipient's status changes, an `after_update_commit` callback broadcasts Turbo
   Streams that replace two regions: the recipient's own `<li>` row, and the
   progress `<turbo-frame>` holding the status badge, the "Sent 5 of 10" counter,
   and the progress bar — so individual recipients and the aggregate progress
   each update independently, without a refresh.

## Architectural notes

- **Status is modeled as enums** (`Campaign`: pending/processing/completed,
  `Recipient`: queued/sent/failed) backed by integer columns, with a composite
  index on `(campaign_id, status)` for the per-status counts. A `recipients_count`
  counter cache keeps the dashboard list free of N+1 count queries.
- **Broadcasting lives in the model**, not the job. Any status change — from the
  job, the console, or a future retry path — pushes the same Turbo Stream
  update, so the job stays focused on orchestration.
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

## Future improvements (with 40 hours)

- **Real delivery + retries**: pluggable email/SMS adapters with Sidekiq retry,
  exponential backoff, and a per-recipient error message column.
- **Resilient progress**: derive progress from `GROUP BY status` counts and add
  a "retry failed" action to re-dispatch only the failures.
- **Throughput**: fan out delivery into one job per recipient (or batches) so a
  large campaign isn't bound to a single worker thread, and add idempotency so a
  re-run never double-sends.
- **Product surface**: authentication and per-account scoping, campaign
  scheduling, CSV import with validation/preview, and webhook ingestion for real
  delivery/bounce events.
- **Observability**: structured logging, Sidekiq metrics, and dashboards for
  delivery and failure rates.
- **Testing**: factory/contract tests for the delivery adapters and a CI matrix.
