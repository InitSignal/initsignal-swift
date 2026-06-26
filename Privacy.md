# Privacy

InitSignal Swift sends one operational first-launch event per install/app lifetime outside debug mode.

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
- Random event UUID for deduplication only

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

The event UUID is used only to deduplicate retries. It is not a persistent user identity.

When `options.debug = true` in a local debug build, the SDK sends a fresh development signal on each app launch for integration testing and does not mark the production first-launch signal as sent.
