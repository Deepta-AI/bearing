# Rotation by secret type

Every procedure: create new, accept both, cut over, revoke old, verify.
The agent prints the steps; the engineer performs them. Values are
never pasted into the conversation.

| Type | Period | Dual-read | Create new | Cut over | Revoke old | Verify |
| --- | --- | --- | --- | --- | --- | --- |
| API key (third party) | 90 days | usually yes | provider console, new key | update the manager, redeploy readers | delete old key at provider | one live call succeeds; provider log shows the new key id |
| OAuth client secret | 180 days | provider dependent | add a second secret on the client | update the manager, redeploy | remove the first secret | a full login round trip |
| Signing key (JWT, cookies) | 90 days | yes, by `kid` | generate, add to the key set as next | sign with new, verify with both | drop old after max token lifetime | tokens issued before cut-over still verify until expiry |
| Webhook secret (inbound) | 180 days | sender dependent | new secret at the sender | verify against both for the replay window | remove old | one delivery verifies with the new secret |
| Webhook secret (outbound, per consumer) | on request | yes | issue new to the consumer | sign with both headers during the window | stop sending old | consumer confirms |
| Database credential | 90 days | yes (two users) | create user B with the same grants | switch the connection string, redeploy | drop user A | connections show only user B |
| TLS private key | at certificate renewal | no | new key and CSR | install the new pair | old key deleted | `openssl s_client` shows the new serial |
| SSH deploy key | 180 days | yes | new pair, add public key | switch the pipeline | remove the old public key | one deploy succeeds |
| Cloud access key | 90 days, prefer roles | yes | second key on the principal | update the manager | deactivate then delete | audit log shows the new key id only |
| Encryption key (data at rest) | yearly | yes, by key version | new version in the KMS | encrypt with new, decrypt with any | disable old after re-encryption | re-encryption job count matches row count |

## Leak response, in order

1. Revoke at the provider. Nothing else first.
2. Rotate per the row above; redeploy every reader.
3. Scrub: the engineer runs the history rewrite, never the agent.
   Print for them: `git filter-repo --path <file> --invert-paths`
   (drop a file from all history) or `git filter-repo --replace-text
   <file listing the old values>` (blank the value in place), then the
   force-push, then a notice that every clone must be re-cloned. This
   stops the next reader; it does not unpublish anything.
4. Audit: how long, where, what it could reach, whether it was used
   (provider audit log).
5. Notify: owner, security contact, provider policy, customers when
   their data was reachable.
