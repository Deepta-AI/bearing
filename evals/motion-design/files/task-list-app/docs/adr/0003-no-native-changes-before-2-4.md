# ADR-0003: No new native modules before the 2.4 store release

Status: Accepted

## Context

2.3 went to the stores on 2 September. The runtime version follows the
app version, so every 2.3.x build takes JS-only changes over EAS Update
within a day, while a change that adds or upgrades a package with native
code needs a new store build and review (about a week on iOS, and crews
update slowly).

## Decision

Until 2.4 is cut (planned for November), no package with native code is
added or upgraded. JavaScript-only packages are fine. Work that needs a
native module waits for 2.4 or is done with what is already linked.

## Consequences

Features are built on React Native core and the packages already in
package.json. The 2.4 branch collects the native work.
