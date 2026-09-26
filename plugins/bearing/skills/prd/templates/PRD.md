# PRD: <title>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The PRD is the
     root of the traceability chain: stories, criteria, tests and commits cite
     its REQ ids, and backlog judges and combines them. It records only
     what the input says; anything added is marked inferred:. -->

Source: <file, paste, or "existing PRD re-normalised">   Normalised: <date>
Owner: <name or unconfirmed:>   Tracker epic: <<PREFIX>-<n> or unconfirmed:>

## 1. Problem

<!-- What: what is wrong today and for whom, from the input only.
     Good: carries the input's own evidence (a number, a complaint, a quote);
     a solution the input names goes to Constraints, not here. If the input
     does not state a problem, write "Not in the input" and list it under
     Could not extract.
     Example: "Clinic receptionists re-key 40 to 60 lab reports a day from
     email into the patient record (brief, para 2); errors reach doctors." -->

## 2. Business objectives

<!-- What: the business outcomes this work should produce, one row each,
     with ids B1 upward that every story's "Why it matters" line cites.
     Good: an outcome for the business or its users, not a feature; a
     target is a number with a date, and only when the input calls it a
     target, otherwise target: unconfirmed. A budget, launch date or user
     count from the brief goes to Constraints, not here. Ids are permanent.
     Example: "B1 | Lab reports reach the record without re-keying | 90% of
     reports auto-filed by 31 Mar 2027 | brief, para 4" -->

| Id | Objective | Target (measurable) | Source |
| --- | --- | --- | --- |
| B1 | <outcome> | <number and date, or target: unconfirmed> | <line or quote> |

## 3. Non-goals

<!-- What: what this work will deliberately not do.
     Good: each comes from the input; anything you add to close a scope gap
     is prefixed inferred: and gets a Q-nnn entry in questions.md.
     Example: "- Billing for lab tests is out of scope (brief, para 6)." -->

## 4. Personas

<!-- What: the named roles in the input who use or run the system.
     Good: each persona is a role the input names, with its source. If none
     is named, derive at most one from the verbs and mark it inferred:.
     Example: "Receptionist | 00 end user | front desk staff at a clinic |
     file each lab report against the right patient | brief, para 2" -->

| Persona | Group | Who they are | What they need | Source |
| --- | --- | --- | --- | --- |
| <name> | 00 end user / 01 admin / 02 operator / 03 integration | | | |

## 5. Requirement statements

<!-- What: one row per testable statement found in the input: every must,
     should, shall, needs, can, will, allow, imperative and bullet.
     Good: one capability per id, present tense, the system as subject, with
     the source line; split a sentence joined by "and"; never "As a". A vague
     word (fast, easy, appropriate, some) is kept and marked ambiguous: with
     a Q-nnn entry in questions.md. Keep ids forever: new ones append, dropped ones stay
     marked withdrawn:, and a changed meaning is a new id with the old one
     marked withdrawn: replaced by REQ-nnn. A statement an ADR or the code
     contradicts is marked blocked: Q-nnn. A missing capability is a
     question, never a new REQ.
     Example: "REQ-014 | The system matches an emailed lab report to a
     patient by name and date of birth. | Receptionist | brief, para 3 | none" -->

One testable statement per id. Ids are never reused or renumbered.

| Id | Statement | Persona | Source | Flags |
| --- | --- | --- | --- | --- |
| REQ-001 | The system <does one observable thing>. | | <line or quote> | ambiguous: / blocked: / withdrawn: / none |

## 6. Constraints

<!-- What: fixed limits the solution must live within: technical, legal,
     budget, date, and any solution the input names.
     Good: each has its source; a named product or technology from the input
     lands here, not in the statements.
     Example: "- Must run on the clinic's existing Windows 10 desktops (brief,
     para 7)." -->

## 7. Open questions

<!-- What: the pointer to docs/product/questions.md (templates/questions.md)
     and its counts. Every ambiguous: statement, every inferred: item, every
     gap and contradiction between passages, and the critic's claims when it
     was run, is one Q-nnn entry there, with the decision taken so work is
     not blocked.
     Good: the counts match the register; the PRD never carries a second
     list that can drift from it.
     Example: "12 entries in docs/product/questions.md: 9 open, 4 need your
     confirmation (Q-003, Q-004, Q-009, Q-011)." -->

<N> entries in docs/product/questions.md: <O> open, <A> need your confirmation (<Q ids>).

## 8. Could not extract

<!-- What: every section the input did not cover, and who can supply it.
     Good: names who can supply it, a person or a role; the output contract
     reports "none" when every section came from the input.
     Example: "- Personas: not in the input; the clinic operations lead can
     name who files reports today." -->

## 9. Glossary

<!-- What: domain terms from the input a new engineer would misread.
     Good: the meaning is the input's meaning, with its source, not your own
     definition.
     Example: "LIS | the lab's own information system that emails reports |
     brief, para 3" -->

| Term | Meaning | Source |
| --- | --- | --- |
