# InitSignal Swift

Tiny Swift SDK for sending exactly one first-launch signal to InitSignal.

## Install

Add this package in Xcode:

```txt
https://github.com/bardonadam/initsignal-swift.git
```

## Usage

App delegate:

```swift
import InitSignal

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    InitSignal.start("is_live_...")
    return true
}
```

SwiftUI app:

```swift
import InitSignal
import SwiftUI

@main
struct ExampleApp: App {
    init() {
        InitSignal.start("is_live_...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`start` returns immediately, never throws, and fails quietly if the network or InitSignal service is unavailable.

## Behavior

- Sends one accepted first-launch event per app install/app lifetime.
- If the first attempt fails, retries quietly on later launches using the same event UUID.
- Marks the launch as sent only after InitSignal accepts the event.
- Does not collect user identifiers, sessions, screen views, IDFA, IDFV, Apple ID, email, location, contacts, photos, or files.
- Uses only Foundation and a short-lived ephemeral URLSession request.
