# feature-flags: the flags module shape

Read when you create a flags module in a repository that has none, or review one (step 2).

## Flags module shape

```
Names: one typed enumeration; a string literal flag name anywhere else is a finding.
Parse: "true"/"1"/"on" are on; everything else, including "false" and "", is off.
Enabled(ctx, name) -> bool: reads the source once at start (services) or on refresh (mobile),
  returns the bundled default when the source has no value.
Override for tests: WithFlags(ctx, map) or a fake FlagSource injected in DI.
No network call inside Enabled; mobile refreshes remote config in the background.
```
