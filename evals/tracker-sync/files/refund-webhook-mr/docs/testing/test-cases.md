# Test cases

| Id | Ticket | Case | Level |
|----|--------|------|-------|
| TC-021 | SHOP-118 | A succeeded refund is never downgraded by a later pending update | unit |
| TC-031 | SHOP-142 | A correctly signed refund.updated event is recorded | unit |
| TC-032 | SHOP-142 | An event with a wrong signature is rejected with 401 and not recorded | unit |
| TC-033 | SHOP-142 | A correctly signed event whose timestamp is more than 5 minutes old is rejected (replay) | unit |
