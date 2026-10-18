# Data needs: <feature>

<!-- Template guidance: what each screen of one feature needs from the server,
     written by screen-design after the screens and read by data-model and
     openapi-spec. One "## S-nn <name>" section per screen in the flows
     inventory, each with Fields, Actions and States tables. Checked by
     `states_check.py --needs`. Delete each comment when you fill its section. -->

## S-01 <screen name>

<!-- What: one screen's data needs; the heading carries the flows' screen id.
     Good: every screen of the flows inventory has a section, none invented;
     a screen that needs nothing says so with a `none: <reason>` row in each
     table.
     Example: ## S-01 Members -->

### Fields

<!-- What: each value the screen shows or edits: id (F-nn), field name,
     type, where it comes from, and whether the API already has it.
     Good: Source is `server`, `derived: <how>` or `client: <where>`; Status
     is `exists` or `new` (`new` for every need on a greenfield feature,
     blank only for a `client:` field); the name is the API's name when one
     exists.
     Example: F-02 | invite.expires_at | datetime | server | new -->

| Id | Field | Type | Source | Status |
| --- | --- | --- | --- | --- |
| F-01 | <object.field> | <type> | server | exists / new |

### Actions

<!-- What: each thing the user does that the server must answer: id (A-nn,
     unique across the whole file), the action, what happens on the server,
     and every outcome as `<status> <code>` separated by semicolons.
     Good: the outcomes include each error code the flows' error rows name;
     a client-only action writes `none: <reason>` in Server and leaves
     Outcomes blank; Status is `exists` or `new`.
     Example: A-01 | Send invite | create an invite | 201 created; 409
     already_member | new -->

| Id | Action | Server | Outcomes | Status |
| --- | --- | --- | --- | --- |
| A-01 | <verb noun> | <what the server does> | <status> <code>; <status> <code> | exists / new |

### States

<!-- What: the server condition behind each loading, empty and error state
     of this screen's flows inventory.
     Good: one row per such state, named as the flows name it (`error:
     already_member`); the condition is something the API can be tested
     for, not a restatement of the state.
     Example: empty | the list returns zero members -->

| State | Server condition |
| --- | --- |
| loading | <what is in flight> |
