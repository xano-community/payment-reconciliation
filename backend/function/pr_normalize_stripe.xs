function "pr_normalize_stripe" {
  description = "Map a raw Stripe balance transaction into the canonical processor transaction shape. Stripe reports amounts in the smallest currency unit (cents) and timestamps as epoch seconds. Pure transform — no database writes."

  input {
    json raw { description = "Raw Stripe balance transaction object {id, amount (cents), currency, fee (cents), net (cents), created (epoch s), source}" }
  }

  stack {
    var $r { value = $input.raw }
    var $txn {
      value = {
        processor: "stripe",
        processor_ref: ($r|get:"id"),
        amount: (($r|get:"amount") / 100),
        fee: (($r|get:"fee") / 100),
        net: (($r|get:"net") / 100),
        currency: (($r|get:"currency")|to_upper),
        occurred_at: (($r|get:"created") * 1000),
        payout_id: ($r|get:"source")
      }
    }
  }

  response = $txn

  test "normalizes a Stripe balance transaction (cents to dollars)" {
    input = {
      raw: {id: "txn_1", amount: 1000, fee: 59, net: 941, currency: "usd", created: 1705276800, source: "po_1"}
    }
    expect.to_equal ($response.processor) { value = "stripe" }
    expect.to_equal ($response.processor_ref) { value = "txn_1" }
    expect.to_equal ($response.amount) { value = 10 }
    expect.to_equal ($response.fee) { value = 0.59 }
    expect.to_equal ($response.net) { value = 9.41 }
    expect.to_equal ($response.currency) { value = "USD" }
    expect.to_equal ($response.occurred_at) { value = 1705276800000 }
    expect.to_equal ($response.payout_id) { value = "po_1" }
  }
  guid = "jjXLE2c2A6lJcqcQBRVNZ2q8Zk8"
}
