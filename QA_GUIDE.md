# Manual QA Guide — Campaign Dispatcher

A step-by-step guide for manually testing every feature. Pair it with the rich
seed dataset (`bin/rails db:seed`) and the sample CSVs in `qa_samples/`.

---

## 1. Running the app

```bash
bin/setup           # bundle + db:prepare + build Tailwind
bin/dev             # web + Tailwind watch + Sidekiq (needs Redis running)
# or run individually:
bin/rails server
bundle exec sidekiq -C config/sidekiq.yml
bin/rails tailwindcss:build      # if styles look unstyled
```

Open **http://localhost:3000**. Sidekiq dashboard: **http://localhost:3000/sidekiq**.

> Ruby **3.2.4**, Rails 7.2, PostgreSQL + Redis must be running.

### Reset to a clean test dataset at any time
```bash
bin/rails db:seed          # wipes campaigns, reloads the QA dataset
# or a full rebuild:
bin/rails db:reset         # drop + create + schema load + seed
```

---

## 2. Seeded dataset (what each campaign is for)

| Campaign | Status | Recipients | Sent | Failed | Body | Use it to test |
|---|---|---|---|---|---|---|
| **Spring Product Reviews** | pending | 5 | – | – | ✅ | Start dispatch + live animation |
| **Winter Newsletter** | pending | 3 | – | – | ❌ | Dispatch with **no message** |
| **Q1 Customer Survey** | completed | 6 | 6 | 0 | ✅ | Clean success state |
| **Q2 Feedback Request** | completed | 8 | 6 | 2 | ✅ | **Retry Failed** |
| **Black Friday Promo** | completed | 10 | 7 | 3 | ✅ | Retry Failed + search |
| **Spring Flash Sale** | processing | 6 | 3 | 1 | ✅ | Processing UI (static snapshot) |
| **Spring Cleaning Tips** | completed | 4 | 4 | 0 | ✅ | Search ("spring" → 3 matches) |
| **Annual Report Mailing** | completed | 25 | 20 | 5 | ✅ | Recipient filtering (large list) |

> The **Spring Flash Sale** "processing" row is a static snapshot for UI review —
> it won't auto-advance because no job is running for it. For the *live* animation,
> dispatch a **pending** campaign (Scenario 6).

Sample import files (`qa_samples/`):
- `recipients.csv` — per-campaign upload (has header + one bare-email row)
- `recipients_no_header.csv` — positional, no header
- `campaigns_bulk.csv` — clean bulk import (3 campaigns)
- `campaigns_bulk_messy.csv` — has rows to skip (blank title, missing email)

---

## 3. Test scenarios

### 1) Dashboard stats cards
**Steps:** Load the dashboard.
**Expected:** Four cards — **Campaigns** (8), **Recipients** (67), **Emails sent** (green, = sum of sent), **Active** (amber, = 1 processing). Numbers match the seeded data.

### 2) Search campaigns (live, debounced)
**Steps:** In the "Search campaigns…" box type `spring`.
**Expected:** List updates *without a full reload* to the 3 Spring campaigns. Clear the box → all return. Type `xyz` → "No campaigns match your filters."

### 3) Status filter chips
**Steps:** Click **Pending**, then **Completed**, then **Processing**, then **All**.
**Expected:** List filters instantly to that status. Chips + search **combine** (e.g. `spring` + Completed → "Spring Cleaning Tips" + "Spring Flash Sale" excluded since it's processing).

### 4) Create a campaign (paste + message)
**Steps:** Fill **Title** = `Demo Reviews`, **Message** = `Hi {{name}}, thanks!`, keep **Paste** tab, enter:
```
Ada Lovelace, ada@demo.com
bob@demo.com
```
Click **Create campaign**.
**Expected:** Redirect to the campaign; flash "Campaign created with 2 recipient(s)." The bare-email line becomes a recipient named **bob**. Stats card "Campaigns" increments.

### 5) Message preview & merge tags
**Steps:** Open any campaign with a body (e.g. **Q1 Customer Survey**).
**Expected:** A **Message** block shows the raw body and a **"Preview for {first recipient}"** with `{{name}}` replaced by their actual name. **Winter Newsletter** (no body) shows **no** message block.

### 6) Live dispatch + real-time updates ⭐
**Steps:** Open **Spring Product Reviews** (pending) → click **Start dispatch**.
**Expected:** Status badge → **Processing**; recipients flip **Queued → Sent/Failed** one by one (each takes 1–3s); the **"Sent N of 5"** counter and progress bar advance live; on finish, badge → **Completed**. No page refresh.

### 7) Retry failed recovery loop
**Steps:** Open **Q2 Feedback Request** (completed, 2 failed) → click **Retry 2 failed recipients**.
**Expected:** The 2 failed rows return to **Queued**, status → **Processing**, failed count → 0, then they re-process to Sent/Failed and the campaign completes again. The Retry button only appears when completed **and** failed_count > 0.

### 8) Recipient filtering (in-campaign)
**Steps:** Open **Annual Report Mailing** (25 recipients). Use the **"Filter recipients…"** box: type `acme` (email match), then `lovelace`. Use the status chips **Sent** / **Failed**.
**Expected:** Recipient list filters live within the page (metrics panel stays put). No matches → "No recipients match this filter."

### 9) CSV upload — per campaign
**Steps:** On the new-campaign form, click the **Upload CSV** tab. Title = `CSV Import Test`, choose `qa_samples/recipients.csv`. Create.
**Expected:** 5 recipients created (incl. **omar** derived from the bare-email row). Repeat with `recipients_no_header.csv` (positional) → 3 recipients.

### 10) Bulk CSV import (multi-campaign)
**Steps:** Dashboard → **Bulk import →**. Upload `qa_samples/campaigns_bulk.csv` → Import.
**Expected:** Redirect to dashboard, flash "Imported **3** campaign(s) and **6** recipient(s)." New campaigns: March Onboarding (3), Product Launch Teaser (2), Webinar Invite (1).
**Then:** Import `campaigns_bulk_messy.csv`.
**Expected:** "Imported **2** campaign(s) and **3** recipient(s) (**2** row(s) skipped)." (blank-title + missing-email rows skipped; the blank-name row derives its name from the email).

### 11) UX polish
- **Flash auto-dismiss:** any green/red banner fades after ~4.5s; clicking it dismisses immediately.
- **Button loading state:** Create/Import/Start buttons show "Creating…/Importing…/Starting…" and disable on click.
- **Empty states:** filter to no results on both dashboard and recipient list.

---

## 4. Edge cases & validation

| Test | Steps | Expected |
|---|---|---|
| Missing title | Create with blank title | Form re-renders with "1 error prevented…"; no campaign created |
| Bare-email line | Recipients = `solo@x.com` only | Recipient created, name = `solo` |
| Malformed CSV | Upload a file like `a,"unterminated` to bulk import | Red alert "That file could not be parsed as CSV." — no crash |
| No file chosen | Submit bulk import with no file | Red alert "Please choose a CSV file to import." |
| Double-click dispatch | Rapidly click **Start dispatch** twice | Campaign dispatches **once** (no duplicate sends/counters) |
| Already dispatched | Reload a processing/completed campaign | No Start button; if forced, alert "already been dispatched" |

---

## 5. Real-time multi-tab check
Open the same campaign in **two browser tabs**. Start dispatch in tab A.
**Expected:** Both tabs animate the recipient rows and progress in real time (Action Cable broadcast over the campaign-scoped stream).

---

## 6. Automated tests (sanity)
```bash
bundle exec rspec          # full suite — 57 examples, all green
bundle exec rspec spec/system   # the live Turbo round-trip (headless Chrome)
bundle exec rubocop        # style — clean
```

---

## 7. Known trade-offs (by design)
- **Filtered recipient view + live updates:** a recipient filtered *out* of the list won't receive its live row broadcast until you clear the filter (eventually consistent). The metric panel always stays accurate.
- **Stats cards** refresh on page load, not live (a live global stream was scoped out).
- **Processing snapshot** (Spring Flash Sale) is static — see the note in §2.
