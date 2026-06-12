// List reconciliation exceptions, filtered by kind and status.
query "exceptions" verb=GET {
  api_group = "PaymentReconciliation"

  input {
    text kind? { description = "Filter to one exception kind" }
    text status?="open" { description = "open or resolved" }
    int page?=1 filters=min:1
    int per_page?=50 filters=min:1|max:200
  }

  stack {
    function.run "pr_list_exceptions" {
      input = {kind: $input.kind, status: $input.status, page: $input.page, per_page: $input.per_page}
    } as $result
  }

  response = $result
  guid = "nkpoJ3HNYl8uWswAXeHBLChiIfg"
}
