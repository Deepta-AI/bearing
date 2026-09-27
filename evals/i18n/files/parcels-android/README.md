# parcels-android

The courier app customers use to track their parcels. Kotlin, Jetpack
Compose, minSdk 26, targetSdk 34.

The Gradle wrapper jar is not checked in; CI builds with its own Gradle 8.7
image (`./gradlew lint testDebugUnitTest assembleRelease`).

## Localisation

All user-facing text lives in `res/values/strings.xml`. Hindi
(`values-hi`) is complete. The in-app language picker is in Settings and
uses per-app languages (`res/xml/locales_config.xml`).

Delivery fees come from the API in minor units (`Long`, halalas or paise)
together with an ISO 4217 currency code: SAR for domestic parcels, and
BHD for cross-border parcels from Bahrain.
