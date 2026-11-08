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

## Download

Get the latest Android APK from the [GitHub Releases page](https://github.com/Callumhome/opnsense-network-monitor/releases).

Download `app-release.apk` and install it on your Android device. Android may ask you to allow installation from your browser or file manager.

## Important: You need your own backend

**The Android app is a frontend only. It does not connect directly to OPNsense.** Each installation needs access to an independently hosted, compatible OPNsense Network Monitor backend.

The backend communicates with OPNsense and supplies DHCP device data to the app. OPNsense API credentials must be configured on the backend and must never be embedded in the Android app.

### Suggested home-lab deployment

You can host the backend on your own Proxmox server, for example in a dedicated LXC container.

You will need:

- A Proxmox host (or another server) to run the backend
- A separate backend service compatible with this app's API
- Network connectivity from the backend to your OPNsense firewall
- OPNsense API credentials configured securely on the backend
- Network connectivity from your Android phone to the backend
- The backend's reachable address and port

High-level setup:

1. Deploy a compatible backend service in your Proxmox LXC or another server environment. **The backend is not included in this Android repository or APK.**
2. Configure the backend with your OPNsense firewall address and API credentials, following the backend project's own installation instructions.
3. Ensure the backend is reachable from your phone over your local network. Configure firewall rules as needed.
4. Open OPNsense Network Monitor on Android.
5. Open **Settings** and enter the backend base URL, for example `http://192.168.1.160:8000` (replace with your own backend address and port).
6. Save the settings and return to the device list.

The example URL is illustrative only. It will not work unless a compatible backend is deployed and listening at that address.

For production deployments, HTTPS is recommended. Do not expose the backend publicly without appropriate authentication and security controls. Handle OPNsense API credentials securely.

## Requirements for developers

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

Configure the backend URL within the app's Settings screen. The backend handles communication with OPNsense. OPNsense credentials should remain on the backend and must not be embedded in the Android application.

For production deployments, HTTPS is recommended.

## License

License information will be added before the public release.
