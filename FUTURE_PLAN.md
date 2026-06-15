# Future Plan (next ~40 hours)

Where this goes next. Hours are build estimates (design, code, tests), not
calendar time. Everything here sits on top of what's already in place: the
campaign state machine, the locked fan-out, the counter caches, and the Turbo
real-time layer.

The main goal is to stop campaigns being a manual thing. Today someone creates a
campaign and clicks dispatch. The real win is the app noticing a delivered order
with no review and queueing that customer on its own, with enough limits that we
never spam anyone.

## 1. Automation engine (~14h)

The big one, and most of the value.

New models:

- `Customer` (name, email, opted_out_at, last_contacted_at)
- `Order` (customer, external_id, delivered_at, status)
- `Review` (order, rating, body, submitted_at)
- `Recipient` gains `order_id`, `reminder_count`, and a `token` (has_secure_token)
- `Campaign` gains an `origin` flag (manual vs automated) so generated and
  hand-made campaigns live side by side.

Two triggers feed it. When an order is marked delivered, schedule a job a few
days out so the customer has time to actually use the product. Separately, a
daily cron job scans for delivered orders that are past the delay, have no
review, and have no request already out, batches those into an automated
campaign, and runs them through the existing dispatch.

All the "should we contact this person about this order" logic goes in one place,
an eligibility check on the order, so the event path and the cron path can't
disagree. It covers: don't ask twice for the same order, stop if a review already
exists, respect opt-out, cap how often a customer is contacted, and cap reminders
at two.

Each recipient gets a tokenized link (`/r/:token`) to a small public review form,
no login. Submitting writes the Review, which makes the eligibility check fail
from then on (so further asks stop automatically) and gives us a conversion rate
per campaign.

Done when a seeded delivered order turns into a sent request on its own,
submitting through the link records the review and updates conversion, and the
next reminder doesn't go out.

## 2. Pause, scheduling, and retry (~6h)

Bulk retry of failed recipients already exists. A few additions:

- Pause/resume. Add a `paused` state (processing → paused → processing). The
  dispatch job checks state under the lock before queueing the next recipient,
  children bail out if the campaign is paused, and resume picks up the
  still-queued recipients the same way retry does. Button in the metrics panel.
- Scheduling. Let a campaign launch at a future time instead of dispatching
  right away. A `scheduled_at` column plus a recurring job that starts due
  campaigns, surfaced in the create form and on the campaign page.
- Per-recipient retry and backoff. Today retry is all-or-nothing on the failed
  set. Add retrying a single recipient, plus exponential backoff on transient
  failures so they recover without anyone clicking.

## 3. Real sending (~6h)

The send is faked today. To make it real:

- A small `Notifier` interface with email (ActionMailer plus a provider like
  Postmark) and SMS (Twilio) behind it. The current sleep-and-coinflip becomes
  the fake adapter used in dev and tests.
- A webhook endpoint for delivery, bounce, and complaint callbacks that updates
  recipient status and builds a suppression list, so hard bounces and complaints
  never get contacted again.
- Store the provider's failure reason per recipient (a `failure_reason` column)
  and show it on the row, so a failure is debuggable instead of just a red dot.
- Recipients gain a channel and contact value so a campaign can go out over email
  or SMS; today's single-email model is just the email case of that.
- Per-provider rate limiting so a large campaign stays inside send quotas.

## 4. Reporting (~4h)

- Make the stat cards update live (a global stream broadcast on campaign change)
  instead of only on reload.
- A funnel and trend view: delivered → requested → reviewed → converted, per
  campaign and overall, with failure and conversion rates. CSV export of results.

## 5. Auth and multi-tenancy (~4h)

- Devise for login, scope everything to an account (campaigns, customers,
  orders), account-scoped cable streams, and basic auth on the Sidekiq
  dashboard.
- Smaller hardening: an audit log for state changes, rate limiting on the public
  token endpoint, tighter CSV limits, and setting allowed_request_origins for the
  cable connection in production.

## 6. Scale and reliability (~3h)

- Move the fan-out to Sidekiq Batches with a batch callback that finalizes the
  campaign, so the master job isn't holding every recipient id in memory. Add
  idempotency keys, a dead-letter queue with a small UI to inspect and replay
  poisoned jobs, and a circuit breaker that pauses a campaign if a provider
  starts erroring.
- Trigram indexes for search, pagination on long lists, and error tracking
  (Sentry) plus delivery/failure metrics.
- Contract tests for the delivery adapters and a CI matrix across the Ruby and
  Rails versions we support.

## 7. UI and UX (~3h)

- Campaign edit, clone, and delete; recipient pagination; bulk recipient actions;
  toast notifications; drag-and-drop CSV with a preview and per-row validation;
  loading states; keyboard and accessibility work; optionally dark mode.
- A message editor with live preview, a variable list (name, order_id), and a
  "send a test to myself" button.

## Hours

| Area | Hours |
|---|---|
| Automation engine | 14 |
| Pause, scheduling, retry | 6 |
| Real sending | 6 |
| Reporting | 4 |
| Auth and multi-tenancy | 4 |
| Scale and reliability | 3 |
| UI and UX | 3 |
| Total | 40 |

## Order I'd do it in

1. Automation engine plus the lifecycle controls first (~20h). That's the actual
   differentiator.
2. Real sending and reporting (~10h). Makes it usable and shows results.
3. Auth, tenancy, scale (~7h).
4. UI polish (~3h), spread across the rest.

## Assumptions and open questions

- This needs an "order delivered" signal from somewhere, a webhook or a sync from
  the orders system. If there isn't one yet, start by importing orders via CSV or
  a small admin screen.
- The delay, frequency cap, and reminder limit should be config, not hardcoded,
  so they can be tuned per client without a deploy.
- Provider choice (Postmark vs SendGrid vs Twilio) sits behind the adapter, so
  swapping it is cheap.

## Not in this 40h

Billing, a public API, mobile apps, send-time optimization, i18n. Worth doing
later, just not now.
