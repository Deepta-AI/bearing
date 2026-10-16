# flutter: verifying

Read when about to run the gate or report a result: finding the SDK, offline resolve, time limits, the untouched base.

- Find the SDK before saying it is missing: `command -v flutter`, then
  `~/flutter/bin/flutter`, `.fvm/flutter_sdk` or `fvm flutter`. Report
  the version that ran.
- Resolve offline (`flutter pub get --offline`). When a pinned package is
  not cached, do not edit `pubspec.yaml` to make it resolve; test on a
  copy in your own scratch folder with `dependency_overrides` and report
  it as that ("tests pass on a copy with X overridden"), never as "make
  check passes". Nothing outside the repository and your scratch folder
  changes.
- Run tests under a time limit (`timeout 300 flutter test`) so a hanging
  test is a finding, not a stuck session. Stop only processes you started,
  by their PID; never `pkill` or `killall` by name or pattern, which ends
  other sessions' `flutter` runs on the same machine.
- Run the gate on the untouched base first. What fails there is the
  base's: report it as pre-existing and leave it alone (no reformatting
  of files the change does not touch, no edits to unrelated doc
  comments) unless the user asked for it; a separate change fixes it.
  The files you wrote must pass format and analyze on their own.
- The final message separates what ran (where, with what result) from
  what did not, and lists risks found but left alone.
