// Idempotently upsert a batch of internal transaction records.
query "internal/ingest" verb=POST {
  api_group = "PaymentReconciliation"

  input {
    json transactions { description = "Array of internal transaction objects {external_ref, amount, currency?, occurred_at?, order_id?, status?}" }
  }

  stack {
    function.run "pr_ingest_internal" {
      input = {transactions: $input.transactions}
    } as $result
  }

  response = $result
  guid = "juRKOdjK5rYptCcRnQD_iBo1MIU"
}
