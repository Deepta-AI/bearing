# 2. When we ask for notification permission

Status: Accepted (2026-08-19)

## Context

Android 13 and later and iOS show the system notification prompt a
limited number of times; a user who denies it has to find the setting
by hand. Prompts shown at first launch, before the user has a reason,
were denied by most users in our last app.

## Decision

The app never asks for notification permission at launch. It asks once,
right after the user's first order is placed, after an in-app screen
that explains order updates. Users who declined can turn updates on from
Profile, which opens the system settings.

## Consequences

Users who never order never see the prompt, which is fine: there is
nothing to notify them about.
