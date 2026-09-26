# Screen design changes: <feature>

<!-- Template guidance: the trail of feedback rounds on one feature's screen
     prototypes: every comment the user gave, the change it caused and the
     file:line where it landed. The next round, design-critique and the
     developer read it to see why a screen looks the way it does. Edits are
     surgical, so each change points at a line, not a rewritten file.
     Delete each comment when you fill its section. -->

Path: docs/design/screens/<feature>/
Inventory: <flows path | stories | code | brief>   Tokens: <source>
Framework: <web | react | react-native | compose | swiftui>

One section per round, newest last. Every change names the file and
line so the next round and the review can find it. A round with no
comment is still recorded, because three of them end the loop.

## Round 1: <YYYY-MM-DD>

<!-- What: one round: the counts, one row per comment received, what was
     not changed and why, and whether the loop continues.
     Good: the comment is quoted in the user's words; the change is one
     sentence and Where is a file:line in the prototype (a token change
     lands in the token block); the screens touched are re-shot or the
     line says browse absent; a round with no comment is still recorded,
     because three of them end the loop.
     Example: 2 | S-03 | "The total gets lost next to the button" | total
     moved above the Pay button, type role title | S-03-payment.html:212 -->

Comments received: N   Changes: N   Re-shot: <ids | none | browse absent>

| # | Screen | Comment (the user's words) | Change | Where |
| --- | --- | --- | --- | --- |
| 1 | S-01 | "<comment>" | <what changed, one sentence> | S-01-name.html:<line> |

Not changed: <comment and why, or none>
Stop condition: <continuing | user said done | 3 rounds without comments>
