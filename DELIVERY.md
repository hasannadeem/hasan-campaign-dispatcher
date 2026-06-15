# Delivery Summary

A short handover: what was built, how to evaluate it, and the decisions behind it.
For setup and feature detail see the [README](README.md); for what comes next see
[FUTURE_PLAN.md](FUTURE_PLAN.md).

## What was delivered

The core flow — create a campaign, add recipients, dispatch, and watch each one
move from queued to sent/failed in real time — plus a set of features that take it
from a single-screen tool toward a usable product:

- Dashboard with summary stats, live search, and status filters.
- Campaign messages with `{{name}}` personalization.
- Recipients via paste or CSV upload, and bulk import of many campaigns from one
  CSV.
- Retry of a completed campaign's failed recipients, leaving the sent ones alone.
- Per-campaign recipient search/filtering and created/updated timestamps.

Under the hood:

- A fan-out background engine (one job per recipient) that is idempotent and
  row-locked, so double-clicks and retries can't double-send or corrupt totals.
- Weighted Sidekiq queues, retry-with-backoff, and an auth-gated dashboard.
- A hardened schema: enums with DB CHECK constraints, NOT NULL, counter caches,
  a composite index, and a cascading foreign key.

## Evaluate it in ~5 minutes

```bash
bin/setup && bin/dev      # then open http://localhost:3000
```

1. The dashboard shows the seeded campaigns and summary stats. Try the search box
   and the status filter chips.
2. Open a **pending** campaign and click **Start dispatch** — recipients flip and
   the progress bar advances live, no refresh.
3. Open a **completed** campaign that has failures and click **Retry** — the failed
   recipients re-queue and re-send while the already-sent ones stay put.
4. From the new-campaign form, switch to **Upload CSV**, or use **Bulk import** to
   create several campaigns from one file.

## Test coverage

```bash
bundle exec rspec      # 64 examples: model, request, job, service, and system
bundle exec rubocop    # clean
```

System specs drive a real headless browser to verify the live Turbo updates,
search, filtering, retry, and CSV flows end to end. RuboCop is clean and Brakeman
reports no code vulnerabilities (only Ruby/Rails end-of-life advisories, which
can't be cleared without dropping Rails 7.x).

## Key decisions

- **Fan-out, not one sequential job.** Each recipient is its own worker, which is
  how this scales to large campaigns. Correctness under concurrency comes from
  processing only `queued` recipients and doing the recipient claim plus counter
  update inside the campaign's row lock.
- **Real-time split by ownership.** A recipient broadcasts its own row; the
  campaign broadcasts the aggregate metric panel. Both are driven by counter
  caches, so the live broadcasts run no database queries.
- **Counter caches over status scans.** Progress and dashboard figures read three
  integer columns on the campaign rather than counting recipient rows.
- **One email per recipient.** A single contact keeps the model simple; SMS and
  multi-channel are an adapter swap in the future plan.

## Known boundaries

- The send is simulated (a short delay plus ~10% random failure); there is no real
  provider, suppression list, or rate limiting yet.
- No authentication or multi-tenancy.
- Dashboard stats refresh on page load, not over a live stream.
- On a filtered recipient view, a row filtered out of the list won't receive its
  live update until the filter is cleared (the metric panel stays accurate).

All of these are addressed in [FUTURE_PLAN.md](FUTURE_PLAN.md).
