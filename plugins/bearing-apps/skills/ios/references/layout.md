# ios: the repository layout

Read when you place a new screen, feature module, config file or lane.

```
App/<Name>App.swift          entry point: build the container, show ContentView
App/AppContainer.swift       composition root and the \.container environment key
App/ContentView.swift        screens and views; one file per screen
App/Assets.xcassets          AppIcon, AccentColor
App/PrivacyInfo.xcprivacy    privacy manifest (required-reason APIs, data types)
App/Localizable.xcstrings    String Catalog; every user-facing string
Packages/<Name>Kit/          local package: builds and tests without Xcode
  Sources/Core/              AppError, SecretStore (Keychain), WallClock
  Sources/Networking/        APIClient (URLSession, async, typed errors), Endpoint
  Sources/Features/<F>/      Model, Service, ViewModel per feature
  Tests/{Core,Networking,Features}Tests/
project.yml                  XcodeGen spec; the .xcodeproj is generated and ignored
Config/{Debug,Release}.xcconfig   API_BASE_URL and build settings per configuration
fastlane/                    beta lane (TestFlight); the engineer runs it
Makefile                     the only entry point: help setup generate dev check fix test doctor
```
