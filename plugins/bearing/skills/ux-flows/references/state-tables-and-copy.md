# ux-flows: state tables and copy rules

Read when: step 4, writing the state table and the copy of every cell.

4. State table per screen: loading, empty, error and success always;
partial when the screen shows a list, a batch, or data from more than
one source; offline when the feature writes data or targets a phone.
Each cell says what the user sees and gives the copy. A cell that
cannot occur reads `n/a: reason`, never blank. Copy rules: the button
carries a verb; every error says what happened and gives a next step
the user can take on that screen, a control or a pointer, even when
the answer is "nothing to do" ("Ana is already a member. View her
row."); the empty state invites the first action; no apology words.
