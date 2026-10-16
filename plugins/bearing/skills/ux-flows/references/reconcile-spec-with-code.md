# ux-flows: reconcile the spec with the code

Read when: step 2, before drawing anything, and again when a re-issue changes the inputs.

2. Reconcile the spec with the code before drawing anything. The stories
say what someone wants; the code says what ships today, and a flow
written from the stories alone promises things the product does not
do. For every action the flow touches, open its handler and write a
short ledger in the package (section 0 of the template):
- Rejections: every error code or message the handler can return,
  read from the code, not the story, including the lookup miss (an
  unknown id or token) and any path that throws outside the error
  type (a missing session or record dereferenced), which reaches the
  user as a generic 500. Each becomes its own error cell in step 4,
  with copy; a 500 path is also a backend note.
- Who is calling: what each handler needs from the session (signed
  in, which account, which workspace or context) and what it does
  without it. A user arriving from outside (an email link, a
  notification) comes in every session state: signed out with no
  account, signed out with an account, signed in as someone else,
  signed in correctly. Trace each through the handlers: the sign-up
  that rejects an existing address, the sign-in that opens the wrong
  context for a user who belongs to two, the call that crashes when
  nobody is signed in. Each is a path in the flow.
- Numbers and how they are counted: expiry, rate limits, quotas, seat
  or item caps, prices, sizes. Read the counting rule too: does the
  current user count, do pending items hold a slot, does an expired
  one still hold it, is the window fixed or rolling and is it shared
  (per workspace, not per user or per dialog). Then compute the
  numbers the user will see for the scenario in the request, on the
  date it happens ("a new Starter workspace can invite 4, not 5";
  "12 at $8 is $96 a month"; "10 a minute, so 2 wait"). A spec value
  that differs from the code changes every number derived from it
  (an invite still pending under the spec's expiry has expired under
  the code's, so it holds no seat and no longer blocks a re-invite).
- Numbers other documents state: a PM note, a ticket or a review
  that quotes a count, a price or a date was usually worked out from
  the spec. Recompute it from the code and the records; where it
  differs, say so with both figures.
- Routes and endpoints: every link, page and API call the flow relies
  on, checked against the router and the registered endpoints, and
  one hop further: when a recovery sends the user to an existing page
  ("go to billing to upgrade"), check that page's own control works.
  A link that points at an unregistered route, a step with no
  endpoint, or a field the record does not store (a name shown on a
  screen that no model carries) is `new` or a dependency, never
  described as existing.
- Guards the handler does not make: what happens when the item changed
  between the user seeing it and acting on it (accepted, removed,
  expired, changed by another person). If the code succeeds anyway or
  gives a misleading reply, that is a state to design and a backend
  note.
- Spec against code: each disagreement (a number, a permission, a
  missing path, an ADR the story contradicts) is a row with both
  sources. Until product decides, copy states what the code does, or
  reads the value from the record ("Expires 4 Oct, 14:00"); the spec's
  value never appears in copy or examples as fact. The conflict goes
  to open questions with what ships if nobody decides.
