# User flows

<!-- Template guidance: the journeys the backlog adds up to, at least one
     per epic, each from what triggers it to the state it leaves the user
     in, so designers and testers meet the stories in the order a user
     does and every failure has an owner. Error paths are written as
     deliberately as the happy path. The coverage gate fails an epic with
     no journey here. Every comment says what goes there (What), what a
     strong entry has (Good) and an example (Example). Delete each comment
     when you fill its section. -->

Backlog: docs/product/backlog.md   Built: <date>
Flows: F   Screens named: S

## Flow F1: <journey name, in the user's words> (EP-nn)

<!-- What: one complete journey for one epic: who, on what, what starts
     it, and which stories it exercises. Repeat this block per flow, F1
     upward.
     Good: the persona is one from the PRD; platforms are the ones the PRD
     names for this journey (web, Android, iOS, desktop), never "all";
     the trigger is a real-world event, not "the user opens the app";
     Exercises lists every story a step or path below names.
     Example: "Persona: Receptionist (group 00). Platforms: desktop web.
     Trigger: the lab emails the morning's reports. Exercises: US-00-012,
     US-00-014, US-00-016" -->

Persona: <name, group nn>   Platforms: <web / Android / iOS / desktop>
Trigger: <the event that starts the journey>
Exercises: US-nn-nnn, US-nn-nnn

### Before it starts

<!-- What: the state that must hold before step 1: accounts, data, other
     people, devices.
     Good: each line is something a tester can set up and check; a
     condition another story creates names that story.
     Example: "- The receptionist has an account with the filing role
     (US-01-002)." -->

- <precondition>

### Steps

<!-- What: the happy path, one row per step, naming the screen, what the
     user does and what the system does in reply.
     Good: the system column names the observable result (a record, a
     message, where focus lands), not "processes the request"; every row
     names the story that delivers it, and a step no story delivers is
     written gap: and reported.
     Example: "2 | Report inbox | opens the first report | shows the
     suggested patient match with the date of birth highlighted |
     US-00-014" -->

| Step | Screen | The user | The system | Story |
| --- | --- | --- | --- | --- |
| 1 | <screen name> | <action> | <observable reply> | US-nn-nnn |

### Alternate paths

<!-- What: where the user chooses differently from a main step, and what
     happens.
     Good: the condition is the user's choice or situation, not a failure
     (failures go below); each row names its story.
     Example: "2 | the suggested match is wrong | searches by phone number
     and picks the patient; filing continues at step 3 | US-00-016" -->

| At step | Condition | What happens | Story |
| --- | --- | --- | --- |
| 2 | <user chooses differently> | <what they do and where it rejoins> | US-nn-nnn |

### When it fails

<!-- What: what can go wrong at each step, what the user sees, and how they
     recover.
     Good: the message is quoted or described exactly; the recovery keeps
     the user's work; an error no story handles is written gap: in the
     Story cell and reported to the user, never dropped.
     Example: "3 | the attachment is not a PDF | 'Cannot read this file.
     Ask the lab to resend it.' | forwards the email to the lab; the report
     stays in the inbox | gap:" -->

| At step | Condition | What the user sees | Recovery | Story |
| --- | --- | --- | --- | --- |
| 3 | <timeout, invalid input, denied> | <message or state> | <retry, edit, undo, contact> | US-nn-nnn or gap: |

### Afterwards

<!-- What: the state the journey leaves the user and the system in.
     Good: checkable end state (records, notifications sent, where the user
     is), so a tester knows the journey finished.
     Example: "The inbox is empty; each report sits on its patient's record
     with the receptionist as the filer." -->

<end state>

## Counts

<!-- What: totals across every flow in this file.
     Good: counted from the tables above; unhandled failures equals the
     number of gap: rows, so a reader can check it.
     Example: "Flows: 4   Steps: 23   Alternate paths: 6   Failure paths: 9
     Unhandled failures: 1" -->

Flows: F   Steps: S   Alternate paths: A   Failure paths: E   Unhandled failures: U
