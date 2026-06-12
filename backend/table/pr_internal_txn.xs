table "pr_internal_txn" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text external_ref filters=trim
    decimal amount
    text currency?="USD" filters=trim|upper
    timestamp occurred_at?
    text order_id? filters=trim
    text status? filters=trim
    bool matched?=false
    json raw?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "external_ref"}]}
    {type: "btree", field: [{name: "matched"}]}
  ]
  guid = "Gbzmwvonb5qr2WiAAdftYs8fbvc"
}
