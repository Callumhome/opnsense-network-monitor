# OPNsense Network Monitor

An Android companion app for monitoring DHCP clients and network availability using an OPNsense Network Monitor backend.

## Features

- Displays DHCP devices supplied by the backend
- Online/offline status and ping latency
- Search by hostname, IP address, or MAC address
- Dynamic network filtering
- Manual refresh and automatic 30-second refresh
- Configurable backend URL
- Backend URL stored locally on the device

## Requirements

- Flutter SDK
- Android SDK
- OPNsense Network Monitor compatible backend

## Build APK

Install dependencies:

```bash
flutter pub get
```

Build the release APK:

```bash
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Backend Configuration

Configure the backend URL within the app's Settings screen.

The backend handles communication with OPNsense. OPNsense credentials should remain on the backend and must not be embedded in the Android application.

For production deployments, HTTPS is recommended.

## License

License information will be added before the public release.
