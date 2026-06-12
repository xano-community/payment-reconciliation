function "pr_ingest_internal" {
  description = "Idempotently upsert a batch of internal transaction records into pr_internal_txn, keyed on external_ref. Re-ingesting the same external_ref updates the row in place (resetting matched to false) rather than duplicating."

  input {
    json transactions { description = "Array of internal transaction objects {external_ref, amount, currency?, occurred_at?, order_id?, status?}" }
  }

  stack {
    var $count { value = 0 }

    foreach ($input.transactions) {
      each as $raw {
        var $ref { value = ($raw|get:"external_ref") }

        db.add_or_edit "pr_internal_txn" {
          field_name = "external_ref"
          field_value = $ref
          data = {
            external_ref: $ref,
            amount: ($raw|get:"amount"),
            currency: (($raw|get:"currency") ?? "USD"),
            occurred_at: ($raw|get:"occurred_at"),
            order_id: ($raw|get:"order_id"),
            status: ($raw|get:"status"),
            matched: false,
            raw: $raw
          }
        } as $row

        var.update $count { value = (($count) + 1) }
      }
    }
  }

  response = {ingested: $count}
  guid = "uIu6rE63w-eez93zr0OPjQrwodA"
}
