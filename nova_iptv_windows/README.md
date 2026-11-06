# NOVA IPTV — Windows-first

This is the Windows-first milestone for a legal IPTV player. It plays user-provided subscriptions and playlists only; no channels or subscription credentials are bundled.

## Requirements
- Flutter stable SDK
- Windows 10/11
- Visual Studio 2022 with **Desktop development with C++** workload

## Run
From this directory:
```powershell
flutter create --platforms=windows .
flutter pub get
flutter run -d windows
```

To build a release:
```powershell
flutter build windows --release
```
The Windows executable bundle is created under `build\windows\x64\runner\Release\`.

## Current starter functionality
- Windows desktop layout
- M3U text parser
- Xtream Codes authentication and live catalogue API client
- Network video playback screen
- Subscription entry dialog for Xtream Codes and M3U URL/content

## Important
- This starter is not yet a production-ready installer.
- M3U URL downloading, secure credential storage, persistent playlist library, EPG, VOD/series screens, and robust playback fallback are planned next.
- Use only playlists and streams you are authorized to access.

## Build automatically on GitHub Actions
This repository includes `.github/workflows/windows-build.yml` and an Inno Setup script. After uploading the project to a GitHub repository on the `main` branch, open **Actions** and run **Build NOVA IPTV for Windows** (or push a commit). When the run succeeds, open the run and download the `NOVA-IPTV-Windows-Installer` artifact. It contains `NOVA-IPTV-Setup.exe`.

Note: this is an early starter build, not a finished commercial IPTV product. Features listed as planned above are not implemented yet.
