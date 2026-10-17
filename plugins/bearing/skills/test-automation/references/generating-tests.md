# test-automation: generating tests

Read when writing tests from planned rows (step 3): naming, units, oracles, locators, the fork, property rows.

3. Generate. For each `planned` row (or the story or TC in `$2`), find the
nearest existing test by feature folder, then fork `test-writer`
(Agent tool) with the row, the nearest test's path and the naming
rule; it writes the test in an isolated worktree and returns the
failing or passing output. The name carries the id: `test("TC-0012 rejects an expired token")`,
`func TestTC0012_RejectsExpiredToken`,
`async def test_tc_0012_rejects_expired_token`,
`fun tc0012RejectsExpiredToken`, `func testTC0012RejectsExpiredToken`,
and `# TC-0012` on line one of a Maestro flow. Where the name cannot
hold the hyphenated id (Go, pytest, Kotlin, Swift), the literal
`TC-0012` also goes in a comment on the line above the test: the
traceability gate links a test to a row by `TC-nnnn` as written, and
`TestTC0012_` or `test_tc_0012_` alone is not linked.
A planned row whose test already exists (a test already carries its
id) gets no second test: run it; when it passes and asserts the row's
expected result, flip the row to `automated` and report that the table
was stale; when it asserts something else, report the difference and
leave the row. Units: the table and the API may count differently
(rupees and paise, seconds and milliseconds, percent and basis points).
Take the table's unit from its header or notes and the API's from the
field name, type or handler; the test sends and asserts in the API's
unit, converted, with the row's own value in a comment beside it
(`25000, // 250.00 rupees`). A test that sends the unconverted number
tests nothing the row describes. Steps become actions,
each oracle in the row becomes its own assertion (`ui:` a visible or
accessible-name assertion, `data:` a read through the API or the store
after the action, `not:` a negative assertion, `effect:` a spy, a mock
or an event capture, `inv:` a check after every action in the test, `ui: matches baseline <name>.png`
a `toHaveScreenshot("<name>.png")` in `e2e/visual/` shaped
like `templates/visual.spec.ts`: API mocked, clock frozen, anything that
changes on its own masked),
and the row's test data is used verbatim through a builder. Locators: role and accessible name first,
test ids second, never CSS paths. A row whose steps cannot be automated
stays `manual-only` with the reason in its title; never a fake test.
Batch rows by feature folder so one fork writes several tests. When the
fork cannot start (no git repository for its worktree, no Agent tool),
write the tests in place under the same rules and say so in the
report.
Property rows: a `unit` row whose oracle is `inv:`, or whose code is
an encode and decode pair, a parser, a normalizer, a validator, a
comparator or money arithmetic, is a property candidate. When the
`property-based-testing` skill is installed, load it through the
Skill tool before forking and use it to pick, per candidate, the
strongest property the code supports from its catalog, the generator
with constraints in the strategy rather than in `assume()`, the
`@example` edge cases from the row's test data, and the library the
repository already uses. Pass those to `test-writer` in the fork
prompt, since the fork has no Skill tool; the test still carries the
TC id and the row's oracles. It contributes the property and the
generator; this skill still owns the row, the name, the gates and the
status. No property-testing library in the repository: adding one is a dependency
the engineer approves, asked once with AskUserQuestion, options "add <library>"
and "use example tests", naming the property it would test;
without a yes (no answer), or when the skill is not installed, the row gets
example tests from its test data and the report says "property: not
run (<reason>)". A property that only proves "no crash" is not worth
the dependency; write the example tests.
