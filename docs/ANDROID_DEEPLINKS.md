# Android deep links

Two kinds of links open this app on Android:

| Kind | Example | Needs a domain/server? | Status in this project |
|---|---|---|---|
| **Custom scheme** (deep link) | `tdeeplink://product/42` | No | ✅ Done and tested |
| **App Link** (verified https) | `https://example.com/product/42` | Yes: `assetlinks.json` on the domain | ⚙️ Configured with placeholder `example.com`. Needs your domain (step 3). |

Files involved:

- `android/app/src/main/AndroidManifest.xml`: the intent-filters (what links Android sends to us)
- `lib/deep_link_parser.dart`: turns the link into a screen
- `lib/main.dart`: listens for links with the `app_links` package and navigates
- `hosting/public/.well-known/assetlinks.json`: the file you upload to your domain
- `scripts/test_deeplink.sh`: sends a link to the emulator

No Kotlin code is needed. `MainActivity.kt` stays as it is, and the `app_links` plugin reads the link from the Activity's intent.

---

## Step 1: Disable Flutter's built-in deep link handler

Inside `<activity android:name=".MainActivity" ...>`:

```xml
<!-- Tell Flutter NOT to handle links itself; app_links does it. -->
<!-- Otherwise Flutter would also push the link path as a route = double navigation. -->
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
```

---

## Step 2: Custom scheme `tdeeplink://` (offline)

Inside the same `<activity>`:

```xml
<!-- One intent-filter = one rule for "which intents may open this activity". -->
<intent-filter>
    <!-- VIEW is the action Android uses when the user taps a link. -->
    <action android:name="android.intent.action.VIEW" />
    <!-- DEFAULT lets the activity receive implicit intents (intents without a class name). -->
    <category android:name="android.intent.category.DEFAULT" />
    <!-- BROWSABLE lets browsers, chat apps, etc. open us from a tapped link. -->
    <category android:name="android.intent.category.BROWSABLE" />
    <!-- Match every link that starts with tdeeplink:// (any host, any path). -->
    <!-- Must be lowercase and match kCustomScheme in lib/deep_link_parser.dart. -->
    <data android:scheme="tdeeplink" />
</intent-filter>
```

Notes:

- Any app can claim any custom scheme. Keep the name unique (an app-specific word, not `app://`).
- Chrome won't open a custom scheme typed into the address bar. It has to be a tapped link, or use `adb`.

---

## Step 3: App Links `https://your-domain/...` (needs a domain)

### 3.1 Manifest intent-filter (already added)

```xml
<!-- autoVerify="true": at install time Android downloads -->
<!-- https://<host>/.well-known/assetlinks.json and checks that it lists this app. -->
<!-- Verified -> links open the app directly, no "Open with..." chooser. -->
<intent-filter android:autoVerify="true">
    <!-- Tapped-link action. -->
    <action android:name="android.intent.action.VIEW" />
    <!-- Allow implicit intents. -->
    <category android:name="android.intent.category.DEFAULT" />
    <!-- Allow links from browsers/other apps. -->
    <category android:name="android.intent.category.BROWSABLE" />
    <!-- App Links must be https. -->
    <data android:scheme="https" />
    <!-- Your domain. TODO: replace example.com (also kWebHost in lib/deep_link_parser.dart). -->
    <data android:host="example.com" />
    <!-- Only these paths open the app; the rest of the site stays in the browser. -->
    <data android:pathPrefix="/product" />
    <!-- Another allowed path prefix. -->
    <data android:pathPrefix="/profile" />
</intent-filter>
```

> All `<data>` tags in one intent-filter are combined, so this filter matches `https://example.com/product*` and `https://example.com/profile*`.
> For subdomains, use a separate host such as `www.example.com`, or `*.example.com`. Each host needs its own `assetlinks.json`.

### 3.2 `assetlinks.json` (upload to your domain)

It must be reachable at exactly `https://<your-domain>/.well-known/assetlinks.json`. The ready-made file is in `hosting/public/.well-known/assetlinks.json`.

Annotated version (**JSON doesn't allow comments**, so upload the clean file, not this one):

```jsonc
// A list: one entry per app (or per signing key set) allowed to open this domain's links.
[
  {
    // "This app may handle all URLs of this domain."
    "relation": ["delegate_permission/common.handle_all_urls"],
    // Which app.
    "target": {
      // It's an Android app (not a website).
      "namespace": "android_app",
      // applicationId from android/app/build.gradle.kts.
      "package_name": "com.example.tdeeplink",
      // SHA-256 of the certificate the APK is signed with. Several are allowed (debug, release, Play).
      "sha256_cert_fingerprints": [
        // Your local DEBUG key (from ~/.android/debug.keystore on this Mac).
        "89:F4:1B:72:88:6A:4D:7D:54:C1:9E:BA:C1:0E:1D:44:7B:4C:E3:DF:AD:19:96:81:03:E2:B3:FD:F9:46:CC:94"
      ]
    }
  }
]
```

Where to get each fingerprint:

```bash
# Debug key (what `flutter run` signs with):
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA256
```

```bash
# Your release key:
keytool -list -v -keystore /path/to/upload-keystore.jks -alias upload | grep SHA256
```

- **Google Play builds** are re-signed by Google. Copy the *App signing key* SHA-256 from Play Console → *Test and release* → *App integrity* → *App signing*. Play Console also shows a ready-made `assetlinks.json` there.
- Before publishing a new build, update the package name if you change it from `com.example.tdeeplink`. Play rejects `com.example.*`.

Hosting requirements:

- HTTPS with a valid certificate. No redirects: `http→https` or `example.com→www` redirects break verification.
- `Content-Type: application/json`.
- Publicly reachable, with no login and no IP restrictions.

### 3.3 Verify

```bash
# Ask Google's checker whether your file is valid for this app:
open "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://example.com&relation=delegate_permission/common.handle_all_urls"
```

On the emulator or device (Android 12+):

```bash
# Force Android to re-download assetlinks.json now:
adb shell pm verify-app-links --re-verify com.example.tdeeplink
```

```bash
# Show the result per domain:
adb shell pm get-app-links com.example.tdeeplink
```

Result codes: `verified` = working. `1024` = failed (wrong fingerprint or package, file not found, or a redirect). `none` = not checked yet.

### 3.4 Developing *without* a domain (dev-only bypass)

You can make Android treat the domain as "approved by the user" even though verification failed:

```bash
# Mark example.com as allowed for this app on this emulator/device (Android 12+):
adb shell pm set-app-links-user-selection --user cur --package com.example.tdeeplink true example.com
```

On a phone, the same switch is in **Settings → Apps → tdeeplink → Open by default → Add link**.

---

## Testing

```bash
# Custom scheme, cold or warm start:
scripts/test_deeplink.sh android "tdeeplink://product/42?ref=email"
```

```bash
# https link (with the package name forced, so it works even before verification):
scripts/test_deeplink.sh android "https://example.com/product/7"
```

To test like a real user, remove the package name at the end of the `adb` command in the script. Android then decides who opens the link: your app if verified, otherwise the browser or a chooser. You can also put the link in a message or note on the emulator and tap it.

Logcat shows every link the app receives:

```bash
adb logcat | grep "Deep link received"
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Error: Activity not started, unable to resolve Intent` | The intent-filter doesn't match (scheme/host/path typo), or the app isn't installed |
| https link opens Chrome instead of the app | Not verified: check `pm get-app-links` and step 3.3 |
| Opens the app but on the wrong screen | Check `parseDeepLink` in `lib/deep_link_parser.dart` |
| Screen opens twice | `flutter_deeplinking_enabled` isn't `false` |
| Works on debug, not on Play build | `assetlinks.json` lacks the Play App Signing SHA-256 |
