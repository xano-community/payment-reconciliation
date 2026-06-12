# Payment Reconciliation (Xano module)

Reconcile your **internal transaction records** against **processor payout data** from **Stripe**, **Adyen**, and **ACH** — automatically matching by reference, then by amount, and flagging every unmatched, mismatched, or duplicate row as a typed exception you can work down to zero.

Drop this module into any Xano workspace. It ships four tables and a small public function surface; you feed it your internal ledger rows plus raw processor payloads, then call `/reconcile` to produce matches and a clean exception queue.

## What you get

**Tables**

| Table | Purpose |
| --- | --- |
| `pr_internal_txn` | One row per internal transaction, keyed by `external_ref` (unique). `matched` flips to true once reconciled. |
| `pr_processor_txn` | One canonical row per processor transaction, keyed by `processor:processor_ref` (unique). Normalized amount, fee, net, currency. |
| `pr_match` | A recorded pairing of one internal row to one processor row, with `match_type` (`exact_ref`/`amount_date`/`manual`) and the `amount_delta`. |
| `pr_exception` | A typed exception (`unmatched_internal`/`unmatched_processor`/`amount_mismatch`/`duplicate`) with `detail` JSON and a workflow `status` (`open`/`resolved`). |

**Public function surface** (call from any XanoScript via `function.run`)

| Function | What it does |
| --- | --- |
| `pr_normalize_stripe` | Pure transform: raw Stripe balance txn (cents) → canonical processor shape. |
| `pr_normalize_adyen` | Pure transform: raw Adyen txn (minor units) → canonical processor shape. |
| `pr_normalize_ach` | Pure transform: raw ACH txn (decimal dollars) → canonical processor shape. |
| `pr_ingest_internal` | Idempotently upsert a batch of internal records. |
| `pr_ingest_processor` | Normalize + idempotently upsert a batch of processor records. |
| `pr_reconcile` | The matching engine: pair internal vs processor rows, record matches + typed exceptions. |
| `pr_list_exceptions` | Filtered, paginated query over the exception queue. |

**HTTP endpoints** (API group `payment-reconciliation`)

| Method | Path | Wraps |
| --- | --- | --- |
| `POST` | `/internal/ingest` | `pr_ingest_internal` |
| `POST` | `/processor/ingest` | `pr_ingest_processor` |
| `POST` | `/reconcile` | `pr_reconcile` |
| `GET`  | `/exceptions` | `pr_list_exceptions` |
| `GET`  | `/matches` | list `pr_match` |

## Install

### Option A — Ask Claude Code
With the [Xano MCP](https://github.com/xano-labs/mcp-server) enabled, paste:

> Install the module at https://github.com/xano-community/payment-reconciliation into my Xano workspace.

### Option B — Xano CLI
```sh
git clone https://github.com/xano-community/payment-reconciliation.git
cd payment-reconciliation
xano workspace push backend -w <your-workspace-id>
```

## How matching works

Reconciliation runs in two passes over every **unmatched** internal transaction, against every **unmatched** processor transaction:

1. **Pass 1 — exact reference.** If a processor row's `processor_ref` equals the internal row's `external_ref`, they pair. If the amounts also agree within `amount_tolerance` (default `0.005`), it's an `exact_ref` match; if the reference matches but the amount doesn't, it's recorded as an `amount_mismatch` exception (with both amounts and the delta in `detail`).
2. **Pass 2 — amount only.** For internal rows with no reference match, the first remaining processor row whose amount agrees within tolerance pairs as an `amount_date` match.

Anything left over becomes an exception: internal rows with no partner are `unmatched_internal`; processor rows no internal row claimed are `unmatched_processor`.

Every consumed row is flipped to `matched=true`, so **re-running `/reconcile` is idempotent** — it only ever processes newly-ingested rows.

## Usage

```xs
// 1. Push your internal ledger rows in:
function.run "pr_ingest_internal" {
  input = { transactions: [
    { external_ref: "ref_1", amount: 10.00 },
    { external_ref: "ref_2", amount: 20.00 }
  ] }
} as $internal

// 2. Push raw processor payloads in (normalized automatically):
function.run "pr_ingest_processor" {
  input = {
    processor: "stripe",
    transactions: $stripe_balance_transactions   // raw from /v1/balance_transactions
  }
} as $proc

// 3. Reconcile:
function.run "pr_reconcile" { input = {} } as $report
// $report => { matched, exceptions, by_kind: { exact_ref, amount_date, amount_mismatch, unmatched_internal, unmatched_processor } }

// 4. Work the exception queue:
function.run "pr_list_exceptions" { input = { status: "open" } } as $queue
```

### Processor field mapping reference

| Canonical | Stripe (balance txn) | Adyen | ACH |
| --- | --- | --- | --- |
| `processor_ref` | `id` | `pspReference` | `trace_number` |
| `amount` | `amount` / 100 | `amount.value` / 100 | `amount` (dollars) |
| `fee` | `fee` / 100 | — | — |
| `net` | `net` / 100 | — | — |
| `occurred_at` | `created` × 1000 (epoch s → ms) | `eventDate` | `effective_date` |
| `payout_id` | `source` | — | — |

## License

MIT — see [LICENSE](./LICENSE).
