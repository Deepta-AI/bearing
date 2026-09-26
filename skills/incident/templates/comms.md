# Incident comms templates

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. These are the
     messages the comms role posts during an incident; incident fills the
     ones the current severity needs and records each in the incident doc's
     Comms log. Fill only the fenced text; everything outside the fence is
     for the author. -->

Filled by `incident comms`, posted by the comms role. Every message
says what users see, what is being done, and when the next update
comes. No cause until the lead confirms it. No names of people, no
vendor blame, no jargon a customer would not know.

## Internal stakeholders (team channel, leadership channel for sev 1 and 2)

<!-- What: the status line for the team and, at sev 1 and 2, leadership.
     Good: visible impact in one sentence, the action under way, the lead
     and comms roles, a next-update time in UTC and the doc link; a
     hypothesis is called one, never stated as the cause.
     Example: "[Incident] Checkout payments failing | sev 1 | status:
     mitigating. Since 14:14Z. Users see: about 1 in 5 payments fail." -->

```
[Incident] <title> | sev <N> | status: <investigating|identified|mitigating|monitoring|resolved>
Since <HH:MM>Z. Users see: <one sentence of visible impact>.
Doing now: <one sentence>. Lead: <name>. Comms: <name>.
Next update by <HH:MM>Z. Doc: <link to incident doc>.
```

## Status page: investigating

<!-- What: the first public entry, posted at declare.
     Good: names the journey in the customer's words and what they may see;
     no cause, no internal service names; a next-update time.
     Example: "Checkout is degraded. We are investigating failures affecting
     card payments. Users may see a payment error. Next update by 15:00 UTC." -->

```
Title: <Journey> is <unavailable|degraded>
We are investigating <elevated errors|slow responses|failures> affecting <journey>.
Users may see <what>. We will post an update by <HH:MM> UTC.
```

## Status page: identified

<!-- What: posted once the lead confirms the cause is found and a fix is
     under way.
     Good: still no technical cause or vendor named; a workaround only if
     support could give it in one sentence.
     Example: "We have identified the cause of failed card payments and are
     working on a fix. In the meantime, saved PayPal checkouts still work." -->

```
We have identified the cause of <impact> and are working on a fix.
<Workaround, if there is one: "In the meantime, <what to do>.">
Next update by <HH:MM> UTC.
```

## Status page: monitoring

<!-- What: posted when a fix is applied and recovery is being watched.
     Good: says the journey is recovering, not that it is fixed; keeps the
     cadence with a next-update time.
     Example: "A fix has been applied and checkout is recovering. We are
     monitoring to confirm the fix holds. Next update by 15:30 UTC." -->

```
A fix has been applied and <journey> is recovering. We are monitoring
to confirm the fix holds. Next update by <HH:MM> UTC.
```

## Status page: resolved

<!-- What: the closing public entry, posted when the impact has stopped.
     Good: exact UTC window, the journey and the impact, one plain sentence
     on what was done, and that a postmortem follows; resolve means the
     impact stopped, not that the cause is known.
     Example: "Between 14:14 and 14:52 UTC, card payments at checkout were
     failing for some customers. We reversed a recent change." -->

```
This incident is resolved. Between <HH:MM> and <HH:MM> UTC, <journey>
was <impact>. <One sentence on what was done.> A postmortem will
follow. We are sorry for the disruption.
```

## Customer note (sev 1 and 2, sent by support or account owners)

<!-- What: the direct note to affected customers for sev 1 and 2.
     Good: the date, UTC window and impact; when money is involved, says
     plainly whether payments were lost and how duplicates are reversed; says
     where and when the review findings will be shared.
     Example: "Subject: Service disruption on 12 Sep 2026, Checkout. Between
     14:14 and 14:52 UTC, some card payments failed." -->

```
Subject: Service disruption on <date>, <product>

Between <HH:MM> and <HH:MM> UTC on <date>, <journey> was <impact>.
<If money: "No payments were lost; any duplicate charge will be
reversed within N days without action on your part.">
The issue is resolved. We are completing a review and will share the
findings <where, when>. If you noticed anything we should know about,
reply to this note.
```

## Cadence

<!-- What: how often each audience hears from us at each severity; keep it
     in line with references/severity.md.
     Good: an update is posted on the cadence even when nothing changed;
     each sent message goes in the incident doc's Comms log with its time.
     Example: "Sev 1 declared 14:14Z: internal 14:15Z, 14:45Z, 15:15Z; status
     page at declare then every 30 minutes; customer note by 15:14Z." -->

| Sev | Internal | Status page | Customer note |
| --- | --- | --- | --- |
| 1 | every 30 min | declare, every 30 min, resolve | within 1 h, and at resolve |
| 2 | every hour | declare, hourly, resolve | at resolve |
| 3 | declare and resolve | only if a customer would notice | none |
| 4 | ticket | none | none |

An update that is late is worse than an update that says "no change".
Post "no change, next update by <time>" on the cadence.
