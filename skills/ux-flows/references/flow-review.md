# Flow review checklist

Run every check. Each gets `pass`, `fixed` (the package was changed) or
`open` (listed under open questions with the check id). A check with
nothing to judge is `n/a: reason`, never skipped silently. Print the
counts: checks run, pass, fixed, open.

## F1. Fewest thoughts, then fewest steps

Walk the happy path counting decisions, not clicks. A decision is any
point where the user must choose between options that are not obvious.
Target: zero decisions that need reading. Three obvious taps beat one
puzzling choice. Fix: split a puzzling choice into obvious ones, or make
the right choice the visible default.

## F2. No dead ends

Every screen, modal and error state has a way forward and a way back.
Back means the user's previous screen or a named exit, not the browser
alone on a modal. Count must be zero; this check cannot be `open`.

## F3. Error recovery on every path

Every error cell in the state tables has a recovery flow: retry, edit the
input, or leave with the work kept. The copy names what happened and what
to do. "Something went wrong" fails. Errors that lose typed input fail.

## F4. State coverage per screen

Every screen has loading, empty, error, success and partial rows. A row
that cannot occur reads `n/a: reason`. Offline is present when the
feature writes data or targets a phone. Empty states carry an action.

## F5. Copy is written, not described

Every cell and control has literal copy in quotes. Buttons start with a
verb and keep their name through the flow ("Publish" makes "Published").
No "Submit", "Continue", "OK" without a noun. No happy talk, no
instructions longer than one sentence.

## F6. Pattern consistency across screens

The same action looks and reads the same on every screen: one name for
delete, one place for the primary action, one way to dismiss a modal, one
confirmation pattern for destructive actions. List every exception.

## F7. Trunk test per screen

Cover everything but the chrome. The user can still tell what product
this is, which screen they are on, what the major sections are, and how
to get back. A screen that fails needs a title or a breadcrumb in the
inventory, not a note.

## F8. Story coverage

Every story id from the source appears in at least one screen row, and
every acceptance criterion that describes a state or an error has a cell
that shows it. List uncovered ids.

## F9. Goodwill drains

Scan the storyboard for: information the user wants hidden until late
(price, time, what will be shared), format punishment on input, questions
that are not needed to finish, interstitials before the task, forced
tours. Each is a finding with the step number and a fix.

## F10. Controls are reachable

Every control has a target size and a keyboard path. Nothing depends on
hover to be found. Focus lands somewhere sensible after every state
change (the error message, the new item, the confirmation).

## F11. Analytics honesty

Every control that changes state has an event from the sheet, or the
`needs event:` marker, or `no sheet`. No event name in the package is
one the sheet does not carry.

## F12. Open questions carry cost

Every open question has an owner, a date and the "if deferred" column
filled. A question with no consequence written is not open; it is either
decided or deleted.
