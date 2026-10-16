# autopilot: what a reviewer checks that the tests do not

Read before the first line of code and again before dod: reuse the sibling's path, conventions versus code, running the build as the user, inputs that break a first version.

A strong run and a merely passing one differ here, not in the documents.

- Reuse the sibling's path, not only its output shape. Read how the
  nearest existing command gets its data (which store function, what it
  normalises, how it handles an old file format or a missing file) and
  call the same function. A new command that reads the raw store
  crashes on the legacy rows its sibling quietly converts.
- Where a conventions document and the code disagree, new code follows
  the document, the old code is left as it is, and the gap goes under
  Noticed with the command that shows it. Silently copying the old
  code's bug and silently fixing it in this MR are both wrong.
- Before dod, run what was built the way the user will, from a shell,
  and read stdout, stderr and the exit status against what the PRD,
  README and conventions promise. Tests the run wrote agree with the
  code by construction; the documents are the independent oracle. A
  promise the program breaks is a bug in one of them, fixed before the
  MR.
- The inputs that break a first version, for the interface in hand:
  - text: case-insensitive means Unicode case folding (`casefold()`,
    not `lower()`: the German sharp s and the Greek final sigma differ);
    a word is letters plus combining marks (categories L and M: `\w`
    and `\pL` alone cut decomposed accents and Indic vowel signs out of
    the word), with NFC normalisation before comparing; bytes that are
    not valid UTF-8 give a clear error or a documented replacement,
    never a stack trace.
  - arguments: missing, empty, repeated, zero, negative, not a number;
    a user's search term is a literal (escaped, or matched without a
    regex), and a word-boundary regex is checked against terms that
    start or end in punctuation, where `\b` does not match beside them.
  - files: missing, unreadable, empty, not the expected format (invalid
    JSON), and an older layout of the same format.
  - errors: the argument library's own output counts; argparse and Go's
    flag print a usage block plus the error, which is not the "one-line
    error" a PRD may have promised. Decide the shape, write it down,
    and test the exact stderr.
- Every example in the README or the design note is run and its output
  pasted from that run, not written from memory.
