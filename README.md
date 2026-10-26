# tdeeplink: deep link playground (Android + iOS)

A small Flutter app for building and testing deep links locally.

| Link | Opens |
|---|---|
| `tdeeplink://product/42?ref=email` | Product screen, id `42`, query `{ref: email}` |
| `tdeeplink://profile/john` | Profile screen, id `john` |
| `https://example.com/product/7` | Product screen (App Link / Universal Link, once your domain is set) |
| `tdeeplink://` or `https://example.com/` | Home |
| anything else | "Unknown link" screen |

The home screen lists every link the OS delivered. It also has buttons that run the parser in-app, without going through the OS.

## Platform setup docs

- [docs/ANDROID_DEEPLINKS.md](docs/ANDROID_DEEPLINKS.md): manifest, `assetlinks.json`, verification, `adb`
- [docs/IOS_DEEPLINKS.md](docs/IOS_DEEPLINKS.md): Info.plist, Associated Domains, `apple-app-site-association`, `simctl`

## Project map

```
lib/main.dart                  listens for links (app_links) and navigates
lib/deep_link_parser.dart      Uri -> screen (pure Dart, unit tested)
test/                          parser + widget tests (flutter test)
android/app/src/main/AndroidManifest.xml   Android intent-filters
ios/Runner/Info.plist          iOS custom scheme
ios/Runner/Runner.entitlements iOS Universal Links domains (inactive until enabled in Xcode)
hosting/                       files to upload to your domain (Firebase Hosting / GitHub Pages / Netlify)
scripts/test_deeplink.sh       send a link to the emulator / Simulator
```

## Quick test (no server needed)

```bash
flutter run   # install on the emulator or Simulator first
```

```bash
scripts/test_deeplink.sh android "tdeeplink://product/42?ref=email"
```

```bash
scripts/test_deeplink.sh ios "tdeeplink://profile/john"
```

## Free hosting for the https verification files

`hosting/public/` contains:

- `.well-known/assetlinks.json` (Android): already holds this Mac's debug key fingerprint
- `.well-known/apple-app-site-association` (iOS): replace `TEAMID` with your Apple Team ID
- `index.html`: a page of tappable test links to open on the phone

**Firebase Hosting** (recommended; `hosting/firebase.json` already sets the right Content-Type):

```bash
npm install -g firebase-tools
```

Create a free project at console.firebase.google.com (no billing needed for Hosting), then:

```bash
firebase login
```

```bash
cd hosting && firebase deploy --only hosting --project <project-id>
```

No `firebase init` needed, because `hosting/firebase.json` already exists. Your domain becomes `<project-id>.web.app`.

**GitHub Pages**: push the contents of `hosting/public/` to a repo and enable Pages. The `.nojekyll` file keeps the `.well-known` folder from being skipped. Your domain becomes `<user>.github.io`, and a project page like `<user>.github.io/<repo>` won't work, because the files must sit at the domain root.

After choosing a domain, replace `example.com` in:

1. `lib/deep_link_parser.dart` → `kWebHost`
2. `android/app/src/main/AndroidManifest.xml` → `android:host`
3. `ios/Runner/Runner.entitlements` → `applinks:`

## Tests

```bash
flutter test
```
