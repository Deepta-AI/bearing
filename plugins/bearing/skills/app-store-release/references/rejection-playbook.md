# Review rejection playbook

Match the rejection text to a row. "Fix" is what to change; "Reply" is
what to say in the resolution centre or the Play appeal. "Build" says
whether a new binary is needed.

## App Store (guideline numbers as cited by App Review)

| Guideline | Typical text | Fix | Reply | Build |
| --- | --- | --- | --- | --- |
| 2.1 Performance: App Completeness | "we were unable to sign in", "crashed on launch", "placeholder content" | Provide a demo account in App Review Information; fix the crash on the reviewer's device class; remove lorem ipsum | Give the demo credentials and the exact steps | often |
| 2.1 (b) Information Needed | "provide a video", "how does the user access X" | Record a screen video of the flow; explain hardware or region gating | Attach the video and the steps | no |
| 2.3.1 / 2.3.3 Accurate Metadata | "screenshots do not reflect the app", "notes mention a feature we could not find" | Screenshots from the shipped build; notes only for what is on | Confirm the corrected metadata | no (metadata only) |
| 2.5.1 Software Requirements | "uses private API", "non-public selectors" | Remove the private call; update the SDK that used it | Name the SDK and version changed | yes |
| 3.1.1 In-App Purchase | "digital content unlocked outside IAP", "links to external purchase" | Route digital goods through StoreKit; physical goods and services may use other payment | Explain which goods are physical | yes |
| 3.1.2 Subscriptions | "subscription terms missing", "no restore purchases" | Show price, period, renewal terms and a Restore button before purchase | Point at the screen with the terms | yes |
| 4.0 Design | "not enough functionality", "web wrapper" | Native features beyond the web page; or a Safari View Controller | Describe the native value | yes |
| 4.2 Minimum Functionality | "limited functionality" | Add the missing core flow; do not argue | Describe what was added | yes |
| 4.8 Sign in with Apple | "third-party login without Sign in with Apple" | Add Sign in with Apple, or drop the third-party social login | Confirm it is added | yes |
| 5.1.1 Data Collection and Storage | "asks for data not needed", "no purpose string" | Purpose strings for every permission; ask at the moment of use; make the login optional when the app works without it | List the purpose strings | yes |
| 5.1.2 Data Use and Sharing | "tracking without ATT prompt", "privacy labels inaccurate" | Add the ATT prompt when any SDK tracks; correct the labels to what the SDKs do | Confirm the labels and the prompt | yes (prompt) or no (labels) |
| 5.1.1 (v) Account Deletion | "no way to delete the account" | Add in-app account deletion that removes data, not only deactivation | Point at the screen | yes |
| 1.2 User Generated Content | "no report or block" | Report, block, and moderation contact for UGC | Describe the moderation | yes |
| 2.3.8 / 2.3.10 | "references to other platforms", "mentions Android" | Remove cross-platform mentions from metadata | Confirm removal | no |

## Google Play (policy names as cited in the rejection email)

| Policy | Typical text | Fix | Reply | Build |
| --- | --- | --- | --- | --- |
| Data safety | "declaration does not match", "undeclared data collection" | Rebuild the form from the SDK list; declare every SDK's collection | Submit the corrected form | no (form) |
| Permissions | "QUERY_ALL_PACKAGES", "SMS or Call Log", "background location", "MANAGE_EXTERNAL_STORAGE" | Remove the permission or use the scoped alternative; file the declaration form only when core to the app | Declaration with the video | yes |
| Target API level | "must target API <n>" | Raise `targetSdk`; test the behaviour changes | none | yes |
| Deceptive behaviour | "misleading claims", "impersonation" | Remove the claim, brand, or icon likeness | Confirm removal | yes or no |
| Families / Teacher approved | "appeals to children" | Set the target audience correctly; remove ads SDKs not certified for families | Confirm | yes |
| Payments | "in-app products outside Play Billing" | Play Billing for digital goods | Explain physical goods | yes |
| Login required | "could not test", "credentials invalid" | Working reviewer credentials in App content > App access | Provide credentials | no |
| Ads / Monetisation | "interstitial on launch", "ads in violation" | Move the ad; follow the ad placement rules | Confirm | yes |
| Metadata | "screenshots with device frames from another device", "keyword stuffing" | Clean listing; real screenshots | Confirm | no |
| Content rating | "questionnaire out of date" | Redo the questionnaire | none | no |

## Reply shape

Two paragraphs: what was changed (or why it is compliant) and where the
reviewer can see it (screen, steps, credentials). No argument about the
policy; ask for a call only when the same rejection repeats twice.
