# Privacy

InitSignal Swift sends one operational first-launch event per install/app lifetime.

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
- Optional install source when safely detectable
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

