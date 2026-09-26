# Test case steps

<!-- Template guidance: docs/testing/test-case-steps.md, the step-by-step
     script for every manual and e2e case in test-cases.md, so a tester who
     has never seen the product can run it and an automation engineer can
     translate it line for line. One table, one row per step; the step id is
     the case id plus a step number (TC-0001.1), so the table stays
     readable by cases_check.py --steps and by a table-to-CSV exporter.
     Keep the header row and its column names. Every comment says what
     goes there (What), what a strong entry has (Good) and an example
     (Example). Delete each comment when you fill its section. -->

Cases: docs/testing/test-cases.md as of <YYYY-MM-DD>. Step ids are permanent;
a retired case keeps its steps.

## Steps

<!-- What: every step of every live manual or e2e case, in order, with the
     one action and what the tester must see before moving on.
     Good: one action per row, with the literal data from the case's Test
     data cell; Expected is observable on screen or through a stated read
     (a query, an API call), never "works" or "as expected"; a data check
     names the query; the last step's Expected is the case's Expected
     result. Unit and integration cases need no rows here.
     Example: "TC-0002.3 | TC-0002 | Press Sign in | 'Email or password is
     incorrect' appears in a role=alert; the URL stays /login" -->

| Step | Case | Action | Expected |
| --- | --- | --- | --- |
| TC-nnnn.1 | TC-nnnn | <one action, with the literal data> | <what the tester sees before the next step> |
