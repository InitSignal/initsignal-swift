# Privacy

InitSignal Swift sends one operational first-launch event per install/app lifetime outside debug mode.

The SDK reads StoreKit 2 app transaction metadata locally to verify that the customer originally downloaded or purchased the current app version. It does not send the original app version to InitSignal.

The SDK collects:

- App bundle ID
- App version
- Build number
- Platform
- OS version
- Device family
- Device model identifier
- App locale/language
- Timestamp
- SDK version
- Optional install source when safely detectable, including `development` when debug mode is enabled

The SDK does not collect:

- User name or email
- Apple ID
- IDFA
- IDFV
- IP address
- Location
- Contacts, photos, or files
- Behavioral sessions
- Screen views
- Cross-app identifiers
- Random event identifiers

Retry attempts are deduplicated from the launch facts already in the event. The SDK does not send a random event identifier.

When `options.debug = true` in a local debug build, the SDK sends a fresh development signal on each app launch for integration testing and does not mark the production first-launch signal as sent.
