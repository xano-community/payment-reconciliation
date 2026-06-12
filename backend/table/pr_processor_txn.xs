table "pr_processor_txn" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text dedupe_key filters=trim
    enum processor {
      values = ["stripe", "adyen", "ach"]
    }
    text processor_ref filters=trim
    decimal amount
    text currency?="USD" filters=trim|upper
    decimal fee?
    decimal net?
    timestamp occurred_at?
    text payout_id? filters=trim
    text status? filters=trim
    bool matched?=false
    json raw?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree|unique", field: [{name: "dedupe_key"}]}
    {type: "btree", field: [{name: "processor"}]}
    {type: "btree", field: [{name: "matched"}]}
  ]
  guid = "HkrmYXbZ2JvF5Tm38Cz_c2BoMoE"
}
