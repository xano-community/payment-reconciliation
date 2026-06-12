table "pr_exception" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    enum kind {
      values = ["unmatched_internal", "unmatched_processor", "amount_mismatch", "duplicate"]
    }
    int internal_txn_id?
    int processor_txn_id?
    json detail?
    enum status?="open" {
      values = ["open", "resolved"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "kind"}]}
    {type: "btree", field: [{name: "status"}]}
  ]
  guid = "puvVZ4DkbIEtujSYz5H3x9a6x4o"
}
