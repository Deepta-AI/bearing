# Single sign-on (SSO)

Updated: 2026-07-14

Enterprise plans can require admins and employees to sign in through your
identity provider over SAML 2.0. Okta, Microsoft Entra ID and Google
Workspace are tested; other SAML 2.0 providers usually work.

## Configure SSO

1. Under Settings > Security > SSO, copy the ACS URL and entity ID.
2. Create a SAML app in your identity provider with those values and map
   the email attribute.
3. Upload the IdP metadata XML in Ledgerleaf and click Test.
4. When the test passes, turn on "Require SSO". Keep one admin with a
   password login as a break-glass account.

If sign-in fails with E-1010, the IdP certificate has usually expired or
been rotated; upload the new metadata.


---
Was this article helpful? If you still need help, open a chat from the
Help menu or write to help@ledgerleaf.example. Ledgerleaf Payroll support is
available Monday to Saturday, 9:00 to 19:00 IST. Copyright 2026 Ledgerleaf
Technologies. All rights reserved.
