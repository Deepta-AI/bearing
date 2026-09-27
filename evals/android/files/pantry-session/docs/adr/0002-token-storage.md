# ADR 0002: Where auth tokens are stored

Status: Accepted (2026-08-11). Supersedes the EncryptedSharedPreferences
plan in the README.

## Context

androidx.security:security-crypto deprecated every API in 1.1.0, so
EncryptedSharedPreferences is not an option for new code.

## Decision

- Tokens are encrypted with a Tink AEAD (AES-GCM). Its keyset is kept by
  `AndroidKeysetManager` and wrapped by an Android Keystore master key.
- The ciphertext is stored in its own DataStore file, never next to the
  plain settings.
- Tokens never appear in logs, crash reports or analytics.
- Tink is already pinned in `gradle/libs.versions.toml`.

## Consequences

Keystore keys never leave the device, so nothing encrypted with them is
usable after a restore on another phone.
