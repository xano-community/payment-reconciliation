// Run the reconciliation engine over all unmatched internal + processor rows.
query "reconcile" verb=POST {
  api_group = "PaymentReconciliation"

  input {
    decimal amount_tolerance?=0.005 { description = "Maximum absolute amount difference to treat two transactions as the same value" }
    int date_window_days?=5 { description = "Maximum day gap for an amount-only match" }
  }

  stack {
    function.run "pr_reconcile" {
      input = {amount_tolerance: $input.amount_tolerance, date_window_days: $input.date_window_days}
    } as $result
  }

  response = $result
  guid = "74CTCEcD3dsIvE2-e3CL82jX5FM"
}
