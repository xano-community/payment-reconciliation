table "pr_match" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int internal_txn_id? {
      table = "pr_internal_txn"
    }
    int processor_txn_id? {
      table = "pr_processor_txn"
    }
    enum match_type {
      values = ["exact_ref", "amount_date", "manual"]
    }
    decimal amount_delta?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "internal_txn_id"}]}
    {type: "btree", field: [{name: "processor_txn_id"}]}
    {type: "btree", field: [{name: "match_type"}]}
  ]
  guid = "1_2itBZBZtFJOvR0bQzNRcXp8R4"
}
