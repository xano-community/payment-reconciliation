function "pr_ingest_processor" {
  description = "Normalize and idempotently upsert a batch of raw processor transactions into pr_processor_txn. Picks the adapter (stripe/adyen/ach) by the processor discriminator, then upserts keyed on processor:processor_ref so re-ingesting the same payout updates rows in place rather than duplicating."

  input {
    text processor { description = "stripe, adyen, or ach" }
    json transactions { description = "Array of raw processor transaction objects (shape depends on processor)" }
  }

  stack {
    precondition ($input.processor == "stripe" || $input.processor == "adyen" || $input.processor == "ach") {
      error_type = "inputerror"
      error = "Unknown processor: " ~ $input.processor
    }

    var $count { value = 0 }

    foreach ($input.transactions) {
      each as $raw {
        var $n { value = {} }
        conditional {
          if ($input.processor == "stripe") {
            function.run "pr_normalize_stripe" {
              input = {raw: $raw}
            } as $sn
            var.update $n { value = $sn }
          }
          elseif ($input.processor == "adyen") {
            function.run "pr_normalize_adyen" {
              input = {raw: $raw}
            } as $an
            var.update $n { value = $an }
          }
          else {
            function.run "pr_normalize_ach" {
              input = {raw: $raw}
            } as $hn
            var.update $n { value = $hn }
          }
        }

        var $key { value = ($input.processor ~ ":" ~ ($n.processor_ref)) }

        db.add_or_edit "pr_processor_txn" {
          field_name = "dedupe_key"
          field_value = $key
          data = {
            dedupe_key: $key,
            processor: ($n.processor),
            processor_ref: ($n.processor_ref),
            amount: ($n.amount),
            currency: (($n|get:"currency") ?? "USD"),
            fee: ($n|get:"fee"),
            net: ($n|get:"net"),
            occurred_at: ($n|get:"occurred_at"),
            payout_id: ($n|get:"payout_id"),
            status: ($n|get:"status"),
            matched: false,
            raw: $raw
          }
        } as $row

        var.update $count { value = (($count) + 1) }
      }
    }
  }

  response = {processor: $input.processor, ingested: $count}
  guid = "Q0d-7EwoO-6Ep8bvdkWK9Hb2V4s"
}
