# feature-flags: removing a flag

Read when you run remove (steps 13 and 15).

13. **A removal must be a no-op in production.** If any environment or
    account still resolves to the branch being deleted, merging the
    removal changes what they see. Do the removal on the branch, but the
    report opens with a blocker: who changes (region, account ids,
    count), why they were held, whether that reason still holds, and the
    safe order: flip them as their own change, observe, then merge the
    removal.
    An override that encodes a commitment (a contract, a regulator, a
    customer's written terms) is not rollout state, and no engineer's
    reading of the CHANGELOG releases it. Deleting the flag must not
    delete what those accounts are owed: either carry it into an explicit
    dated rule that is not a flag (a contract list with end dates, read by
    the feature, with a test for an account inside and past its date),
    keeping the old path for them only; or hold the merge until the
    commitment ends or its owner signs off. Say which, and name the
    owner.

15. Delete the dead branch and the code only it used. Before deleting a
    file, grep its other importers: a shared helper moves or stays. Then
    delete the constant, every read including string-keyed client reads
    (`client read:` lines, the client serialisation such as
    `for_client` or `window.FLAGS`, templates), the `FLAG_` line and the
    comment about it in every env file and manifest, entries in override
    maps (keep the other flags' entries), the off-state test (keep one
    plain behaviour test), and any docs describing the toggle.
    Cached clients still read the key after the server stops sending it:
    a script or bundle cached by browsers or a CDN (unversioned URL, long
    `max-age`) takes the off branch until it expires, and an installed
    mobile build does forever. Change the asset URL (version or
    fingerprint) in the same change, or keep sending the key as a
    constant on for one cache lifetime with a dated note to drop it; for
    mobile, until the versions that read it are unsupported.
    Keep public signatures unless the flag parameter becomes dead; update
    every caller when one changes.

12. **"At 100%" is a claim to verify.** From step 3, list every environment and
    account where the flag does not resolve to the surviving branch. For each,
    find why (the comment next to it, the ticket, the CHANGELOG) and whether
    that reason still holds. Apply the module's own rules when counting: an
    override the module ignores (expired, unknown account) affects nobody; one
    it honours does.
