// List recorded matches between internal and processor transactions.
query "matches" verb=GET {
  api_group = "PaymentReconciliation"

  input {
    text match_type? { description = "Filter by match type: exact_ref, amount_date, manual" }
    int page?=1 filters=min:1
    int per_page?=50 filters=min:1|max:200
  }

  stack {
    db.query "pr_match" {
      where = $db.pr_match.match_type ==? $input.match_type
      sort = {created_at: "desc"}
      return = {type: "list", paging: {page: $input.page, per_page: $input.per_page, totals: true}}
    } as $matches
  }

  response = $matches
  guid = "tCDuWQ8gDA6RTCcQ1E6C3iVXIs0"
}
