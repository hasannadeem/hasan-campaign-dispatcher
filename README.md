# Campaign Dispatcher

A small app for sending review-request campaigns and watching them go out live.
You create a campaign with a message and a list of recipients, hit dispatch, and
the page updates in real time as each recipient flips from queued to sent or
failed.

The send itself is simulated — a short random delay per recipient with the
occasional failure — so the whole thing runs end to end without an email or SMS
provider wired up. Swapping in a real one is a contained change (see Future
improvements).

## Stack

Ruby 3.2 / Rails 7.2, PostgreSQL, Sidekiq + Redis, Hotwire (Turbo + a little
Stimulus) over Action Cable, Tailwind CSS, and RSpec + Capybara.

## Running it locally

You'll need Ruby 3.2, PostgreSQL, and Redis running.

```bash
bin/setup     # bundle, create/migrate/seed the DB, build the stylesheet
bin/dev       # web server + Tailwind watcher + Sidekiq, together
```

Then open http://localhost:3000. The seed data gives you campaigns in every state
to click around in.

`bin/dev` runs everything from `Procfile.dev`. To run the pieces yourself:

```bash
bin/rails server
bin/rails tailwindcss:watch
bundle exec sidekiq -C config/sidekiq.yml
```

Redis backs both Sidekiq (the background jobs) and Action Cable (the live
updates), so it needs to be up before you start. The Sidekiq dashboard is at
`/sidekiq` — open in development, and behind HTTP Basic auth in production when
`SIDEKIQ_WEB_USER` and `SIDEKIQ_WEB_PASSWORD` are set.

## What it does

- Dashboard with summary stats, live search, and status filters.
- Campaigns with a message body you can personalize with `{{name}}`.
- Recipients pasted one per line or uploaded as a CSV, plus a bulk importer that
  turns one `title,name,email` file into several campaigns.
- Real-time dispatch: rows and the progress bar update as the job runs, no refresh.
- Retry the failed recipients of a finished campaign without resending the rest.
- Per-campaign recipient filtering, and created/updated timestamps throughout.

The UI is built to read like a real SaaS dashboard rather than scaffolding —
consistent zinc palette, status pills, a real progress bar, and proper empty
states.

## How the real-time updates work

This is the part I most wanted to get right. The show page subscribes once:

```erb
<%= turbo_stream_from @campaign %>
```

Two things broadcast onto that single stream, split by who owns the data:

- **Each recipient broadcasts its own row** from a model `after_update_commit`.
  The row owns its state.
- **The campaign broadcasts the metric panel** (status, counts, progress bar) from
  its own `after_update_commit`. Aggregate progress is a cross-record rollup, so it
  belongs to the campaign, not to any single recipient.

Both render off counter-cache columns, so the broadcasts don't touch the database.
Stimulus stays out of the live-update path completely — Turbo Streams do all of
it. There are three small Stimulus controllers, but only for things Turbo can't do
on its own: debouncing the search box, the paste/upload toggle, and dismissing
flashes.

## Architecture decisions

- **Fan-out background jobs.** Dispatch enqueues one `DispatchCampaignJob`, which
  takes a row lock, flips the campaign to `processing`, and enqueues one
  `DeliverNotificationJob` per recipient (passing just the id). That's what scales:
  a huge campaign is many small jobs, not one long-running one.
- **Failure handling.** A worker only ever processes `queued` recipients, and it
  does the recipient update and the campaign's counter bump inside the campaign's
  row lock — so a double-clicked dispatch or a Sidekiq retry can't double-send or
  skew the totals. A send that raises is caught and recorded as `failed` for that
  one recipient; it never aborts the rest of the batch. Transient deadlocks retry
  with backoff, and jobs for deleted records are discarded rather than retried to
  the dead set.
- **Schema.** Status is an enum on both models, backed by integer columns with DB
  CHECK constraints so a bad value can't be written even from raw SQL. Progress
  reads from three counter-cache columns on the campaign
  (`recipients_count`, `processed_count`, `failed_count`) instead of counting rows,
  so the dashboard and progress have no N+1. There's a composite
  `(campaign_id, status)` index and a cascading foreign key.
- **Queues.** Sidekiq runs weighted queues — `dispatch` is polled more often than
  `delivery` — so a big campaign's sends don't hold up a newly launched one.

## Trade-offs and priorities

A few deliberate calls about where the effort went:

- **Correctness before breadth.** I spent the first stretch making the core loop —
  create, dispatch, watch it update live — actually robust: idempotent workers,
  row-locked counter updates, a guarded state machine, and a hardened schema. A
  dispatcher that miscounts or double-sends on a double-click isn't worth much, so
  that base came first; the dashboard, search, CSV import, and message body sit on
  top of it.
- **Real-time the idiomatic way, not the clever way.** The live updates are plain
  Turbo Stream broadcasts split by ownership (a recipient owns its row, the
  campaign owns the aggregate). Stimulus is held to three tiny controllers for the
  things Turbo genuinely can't do. Less custom JavaScript to maintain, and behavior
  that's easy to reason about.
- **A simulated send, cleanly seamed.** The send is a `sleep` plus a ~10% failure,
  kept behind a single stubbable method. I'd rather have a clean seam to drop a
  real provider into than a half-wired integration — swapping in Postmark or Twilio
  is an isolated change, not a rewrite.
- **Deferred, not forgotten.** No auth/multi-tenancy yet, stats refresh on page
  load rather than over a live stream, and recipients carry a single email rather
  than a polymorphic contact. Each is a conscious cut with a clear path forward in
  the future plan — scoped boundaries, not loose ends.

## Future improvements (with 40 hours)

The full breakdown is in [FUTURE_PLAN.md](FUTURE_PLAN.md). The short version:

- **Automation engine** — the real product, and most of the value. Notice a
  delivered order with no review and queue that customer automatically, with
  guardrails (per-order dedup, per-customer frequency cap, opt-out, a ~2-reminder
  limit) and a tokenized feedback link that closes the loop and yields a conversion
  rate. Campaigns become the output of a rule, not manual work.
- **Campaign controls** — pause/resume, scheduling, and per-recipient retry with
  backoff.
- **Real delivery** — email/SMS adapters, delivery/bounce webhooks, a suppression
  list, and rate limiting.
- **Reporting, auth, and scale** — live stats and a delivered → reviewed →
  converted funnel, authentication with per-account scoping, and Sidekiq Batches
  for very large fan-outs.

## Tests

```bash
bundle exec rspec      # model, request, job, service, and system specs
bundle exec rubocop
```

The system specs drive a real headless browser to check the live Turbo updates,
search, filtering, retry, and CSV flows end to end.

For hands-on testing, [QA_GUIDE.md](QA_GUIDE.md) walks through every feature
against the seeded dataset (`bin/rails db:seed`), and [DELIVERY.md](DELIVERY.md)
is a short handover with a five-minute evaluation path.
