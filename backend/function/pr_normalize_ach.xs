function "pr_normalize_ach" {
  description = "Map a raw ACH transaction into the canonical processor transaction shape. ACH reports amounts as decimal dollars and uses a YYYY-MM-DD effective date. Pure transform — no database writes."

  input {
    json raw { description = "Raw ACH transaction object {trace_number, amount (decimal dollars), effective_date (YYYY-MM-DD), status?}" }
  }

  stack {
    var $r { value = $input.raw }
    var $txn {
      value = {
        processor: "ach",
        processor_ref: ($r|get:"trace_number"),
        amount: ($r|get:"amount"),
        currency: "USD",
        occurred_at: (($r|get:"effective_date")|to_timestamp),
        status: ($r|get:"status")
      }
    }
  }

  response = $txn

  test "normalizes an ACH transaction (decimal dollars)" {
    input = {
      raw: {trace_number: "021000021234567", amount: 30.00, effective_date: "2024-01-15", status: "settled"}
    }
    expect.to_equal ($response.processor) { value = "ach" }
    expect.to_equal ($response.processor_ref) { value = "021000021234567" }
    expect.to_equal ($response.amount) { value = 30 }
    expect.to_equal ($response.currency) { value = "USD" }
    expect.to_equal ($response.status) { value = "settled" }
  }
  guid = "0HZRwb0fTWHLSn71TKiKk8fEjEM"
}
