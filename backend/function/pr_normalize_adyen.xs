function "pr_normalize_adyen" {
  description = "Map a raw Adyen transaction into the canonical processor transaction shape. Adyen nests the value in an amount object using minor currency units. Pure transform — no database writes."

  input {
    json raw { description = "Raw Adyen transaction object {pspReference, amount: {value (minor units), currency}, eventDate?}" }
  }

  stack {
    var $r { value = $input.raw }
    var $amount { value = (($r|get:"amount") ?? {}) }
    var $txn {
      value = {
        processor: "adyen",
        processor_ref: ($r|get:"pspReference"),
        amount: (($amount|get:"value") / 100),
        currency: (($amount|get:"currency")|to_upper),
        occurred_at: (($r|get:"eventDate")|to_timestamp)
      }
    }
  }

  response = $txn

  test "normalizes an Adyen transaction (minor units to major)" {
    input = {
      raw: {pspReference: "8836_psp", amount: {value: 2050, currency: "usd"}, eventDate: "2024-01-15T00:00:00Z"}
    }
    expect.to_equal ($response.processor) { value = "adyen" }
    expect.to_equal ($response.processor_ref) { value = "8836_psp" }
    expect.to_equal ($response.amount) { value = 20.5 }
    expect.to_equal ($response.currency) { value = "USD" }
  }
  guid = "aMZW76S0RyZQpPajMRbLskueH7k"
}
