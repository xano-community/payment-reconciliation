function "pr_list_exceptions" {
  description = "Query reconciliation exceptions with optional kind and status filters (defaults to open). Newest first, paginated."

  input {
    text kind? { description = "Filter to one exception kind: unmatched_internal, unmatched_processor, amount_mismatch, duplicate" }
    text status?="open" { description = "Filter by status: open or resolved" }
    int page?=1 filters=min:1
    int per_page?=50 filters=min:1|max:200
  }

  stack {
    db.query "pr_exception" {
      where = $db.pr_exception.kind ==? $input.kind && $db.pr_exception.status ==? $input.status
      sort = {created_at: "desc"}
      return = {type: "list", paging: {page: $input.page, per_page: $input.per_page, totals: true}}
    } as $exceptions
  }

  response = $exceptions
  guid = "LZq9bukQ-PBwl_I4hF20xRURbIg"
}
