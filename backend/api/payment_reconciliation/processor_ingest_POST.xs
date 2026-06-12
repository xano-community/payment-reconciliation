// Normalize + idempotently upsert a batch of raw processor transactions.
query "processor/ingest" verb=POST {
  api_group = "PaymentReconciliation"

  input {
    text processor { description = "stripe, adyen, or ach" }
    json transactions { description = "Array of raw processor transaction objects (shape depends on processor)" }
  }

  stack {
    function.run "pr_ingest_processor" {
      input = {processor: $input.processor, transactions: $input.transactions}
    } as $result
  }

  response = $result
  guid = "LYWpEGT-lD8XOVTuZHbFoTmvmTE"
}
