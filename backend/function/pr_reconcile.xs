function "pr_reconcile" {
  description = "Reconcile unmatched internal transactions against unmatched processor transactions. Pass 1 matches by exact external_ref == processor_ref (exact_ref if amounts agree within tolerance, otherwise amount_mismatch). Pass 2 matches any remaining internal row to a processor row by amount within tolerance (amount_date). Records pr_match rows for matches and typed pr_exception rows for unmatched internal, unmatched processor, and amount mismatches. Marks every consumed row matched=true so re-running is idempotent."

  input {
    decimal amount_tolerance?=0.005 { description = "Maximum absolute amount difference to treat two transactions as the same value" }
    int date_window_days?=5 { description = "Maximum day gap for an amount-only match (reserved for future date scoping)" }
  }

  stack {
    db.query "pr_internal_txn" {
      where = $db.pr_internal_txn.matched == false
      sort = {created_at: "asc"}
      return = {type: "list"}
    } as $internals

    db.query "pr_processor_txn" {
      where = $db.pr_processor_txn.matched == false
      sort = {created_at: "asc"}
      return = {type: "list"}
    } as $processors

    var $matched { value = 0 }
    var $exceptions { value = 0 }
    var $by_kind {
      value = {
        exact_ref: 0,
        amount_date: 0,
        amount_mismatch: 0,
        unmatched_internal: 0,
        unmatched_processor: 0
      }
    }
    var $used { value = [] }

    foreach ($internals) {
      each as $internal {
        var $found { value = false }
        var $found_id { value = null }
        var $found_type { value = null }
        var $delta { value = 0 }

        // Pass 1: exact reference match.
        foreach ($processors) {
          each as $proc {
            conditional {
              if (($found == false) && (($used|some:$$ == $proc.id) == false) && ($proc.processor_ref == $internal.external_ref)) {
                var $d { value = (($proc.amount) - ($internal.amount)) }
                var $abs { value = $d }
                conditional {
                  if ($d < 0) {
                    var.update $abs { value = (0 - $d) }
                  }
                }
                var.update $found { value = true }
                var.update $found_id { value = ($proc.id) }
                var.update $delta { value = $d }
                conditional {
                  if ($abs <= $input.amount_tolerance) {
                    var.update $found_type { value = "exact_ref" }
                  }
                  else {
                    var.update $found_type { value = "amount_mismatch" }
                  }
                }
              }
            }
          }
        }

        // Pass 2: amount-only match (only if no reference match was found).
        conditional {
          if ($found == false) {
            foreach ($processors) {
              each as $proc2 {
                conditional {
                  if (($found == false) && (($used|some:$$ == $proc2.id) == false)) {
                    var $d2 { value = (($proc2.amount) - ($internal.amount)) }
                    var $abs2 { value = $d2 }
                    conditional {
                      if ($d2 < 0) {
                        var.update $abs2 { value = (0 - $d2) }
                      }
                    }
                    conditional {
                      if ($abs2 <= $input.amount_tolerance) {
                        var.update $found { value = true }
                        var.update $found_id { value = ($proc2.id) }
                        var.update $found_type { value = "amount_date" }
                        var.update $delta { value = 0 }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Record the outcome for this internal transaction.
        conditional {
          if (($found_type == "exact_ref") || ($found_type == "amount_date")) {
            db.add "pr_match" {
              data = {
                internal_txn_id: ($internal.id),
                processor_txn_id: $found_id,
                match_type: $found_type,
                amount_delta: $delta
              }
            } as $m
            db.edit "pr_internal_txn" {
              field_name = "id"
              field_value = ($internal.id)
              data = {matched: true}
            } as $ie
            db.edit "pr_processor_txn" {
              field_name = "id"
              field_value = $found_id
              data = {matched: true}
            } as $pe
            var.update $matched { value = (($matched) + 1) }
            var.update $by_kind { value = ($by_kind|set:$found_type:(($by_kind|get:$found_type) + 1)) }
            var.update $used { value = ($used|push:$found_id) }
          }
          elseif ($found_type == "amount_mismatch") {
            db.add "pr_exception" {
              data = {
                kind: "amount_mismatch",
                internal_txn_id: ($internal.id),
                processor_txn_id: $found_id,
                detail: {
                  internal_amount: ($internal.amount),
                  processor_amount: ($internal.amount + $delta),
                  delta: $delta
                },
                status: "open"
              }
            } as $ex
            db.edit "pr_internal_txn" {
              field_name = "id"
              field_value = ($internal.id)
              data = {matched: true}
            } as $ie2
            db.edit "pr_processor_txn" {
              field_name = "id"
              field_value = $found_id
              data = {matched: true}
            } as $pe2
            var.update $exceptions { value = (($exceptions) + 1) }
            var.update $by_kind { value = ($by_kind|set:"amount_mismatch":(($by_kind|get:"amount_mismatch") + 1)) }
            var.update $used { value = ($used|push:$found_id) }
          }
          else {
            db.add "pr_exception" {
              data = {
                kind: "unmatched_internal",
                internal_txn_id: ($internal.id),
                detail: {
                  external_ref: ($internal.external_ref),
                  amount: ($internal.amount)
                },
                status: "open"
              }
            } as $exu
            db.edit "pr_internal_txn" {
              field_name = "id"
              field_value = ($internal.id)
              data = {matched: true}
            } as $ie3
            var.update $exceptions { value = (($exceptions) + 1) }
            var.update $by_kind { value = ($by_kind|set:"unmatched_internal":(($by_kind|get:"unmatched_internal") + 1)) }
          }
        }
      }
    }

    // Any processor rows still unmatched become unmatched_processor exceptions.
    db.query "pr_processor_txn" {
      where = $db.pr_processor_txn.matched == false
      sort = {created_at: "asc"}
      return = {type: "list"}
    } as $leftover

    foreach ($leftover) {
      each as $p {
        db.add "pr_exception" {
          data = {
            kind: "unmatched_processor",
            processor_txn_id: ($p.id),
            detail: {
              processor: ($p.processor),
              processor_ref: ($p.processor_ref),
              amount: ($p.amount)
            },
            status: "open"
          }
        } as $exp
        db.edit "pr_processor_txn" {
          field_name = "id"
          field_value = ($p.id)
          data = {matched: true}
        } as $pe3
        var.update $exceptions { value = (($exceptions) + 1) }
        var.update $by_kind { value = ($by_kind|set:"unmatched_processor":(($by_kind|get:"unmatched_processor") + 1)) }
      }
    }
  }

  response = {matched: $matched, exceptions: $exceptions, by_kind: $by_kind}
  guid = "1CY_AfMP_bpV7JwM6wX09mDFqaU"
}
