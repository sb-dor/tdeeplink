# iOS deep links

Two kinds of links open this app on iOS:

| Kind | Example | Needs a domain/server? | Needs a paid Apple account? | Status in this project |
|---|---|---|---|---|
| **Custom URL scheme** | `tdeeplink://product/42` | No | No | ✅ Done and tested on the Simulator |
| **Universal Link** (https) | `https://example.com/product/42` | Yes: `apple-app-site-association` on the domain | Yes, for real devices | ⚙️ Prepared, not active (step 3) |

Files involved:

- `ios/Runner/Info.plist`: registers the custom scheme and disables Flutter's own handler
- `ios/Runner/Runner.entitlements`: the Associated Domains list for Universal Links (**not active yet**)
- `ios/Runner/AppDelegate.swift`, `SceneDelegate.swift`: **no changes needed**. The project uses Flutter's UIScene setup (`FlutterSceneDelegate`), which `app_links` 7.x supports out of the box.
- `hosting/public/.well-known/apple-app-site-association`: the file you upload to your domain
- `lib/main.dart`, `lib/deep_link_parser.dart`: shared with Android

---

## Step 1: Disable Flutter's built-in deep link handler

In `ios/Runner/Info.plist`, inside the top `<dict>`:

```xml
<!-- Tell Flutter NOT to handle links itself; app_links does it. -->
<key>FlutterDeepLinkingEnabled</key>
<!-- false = avoid Flutter pushing the link as a route too (double navigation). -->
<false/>
```

---

## Step 2: Custom URL scheme `tdeeplink://` (offline)

In `ios/Runner/Info.plist`:

```xml
<!-- The list of URL schemes this app registers with iOS. -->
<key>CFBundleURLTypes</key>
<!-- An array: you can register several. -->
<array>
    <!-- One URL type. -->
    <dict>
        <!-- Unique name for this entry; reverse-DNS, usually the bundle id. -->
        <key>CFBundleURLName</key>
        <!-- Our bundle id. -->
        <string>com.example.tdeeplink</string>
        <!-- The actual schemes. -->
        <key>CFBundleURLSchemes</key>
        <!-- List of schemes for this entry. -->
        <array>
            <!-- tdeeplink://... now opens the app. Match kCustomScheme in lib/deep_link_parser.dart. -->
            <string>tdeeplink</string>
        </array>
    </dict>
</array>
```

Notes:

- iOS asks the user "Open in Tdeeplink?" the first time a custom scheme opens the app from outside. That prompt is normal.
- If two apps register the same scheme, iOS picks one unpredictably, so keep the scheme unique.
- Safari won't open a custom scheme typed into the address bar. Tap a link, or use `simctl`.

---

## Step 3: Universal Links `https://your-domain/...` (needs a domain)

### 3.1 Requirements

1. **A paid Apple Developer Program membership** ($99/yr) to install on a real iPhone. The free "Personal Team" can't sign the Associated Domains capability. The Simulator is more lenient.
2. **Your Team ID**, a 10-character code such as `AB12CD34EF`. Find it at developer.apple.com → Account → Membership details.
3. **An https domain** you control (free hosting works; see the root README).

### 3.2 Turn on Associated Domains in Xcode

`ios/Runner/Runner.entitlements` already exists, but Xcode isn't using it yet. I left it inactive on purpose: with a free team, device builds would fail to sign.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **Runner** (target) → **Signing & Capabilities** → choose your paid **Team**.
3. Click **+ Capability** → **Associated Domains**. Xcode links `Runner/Runner.entitlements` and enables the capability for your App ID.
4. Make sure the list contains your domain:

```xml
<!-- Entitlement key for "domains this app is associated with". -->
<key>com.apple.developer.associated-domains</key>
<!-- One string per domain. -->
<array>
    <!-- applinks: = Universal Links for this domain (no https://, no path). -->
    <!-- ?mode=developer = load the file straight from your server, skipping Apple's CDN cache. -->
    <!-- Only honoured on dev builds, and on a device only with Settings > Developer > Associated Domains Development ON. -->
    <!-- TODO: replace example.com; remove ?mode=developer for App Store builds. -->
    <string>applinks:example.com?mode=developer</string>
</array>
```

5. Update `kWebHost` in `lib/deep_link_parser.dart` to the same domain.

### 3.3 `apple-app-site-association` (AASA, upload to your domain)

It must be reachable at exactly `https://<your-domain>/.well-known/apple-app-site-association`, **with no `.json` extension**. The ready-made file is in `hosting/public/.well-known/apple-app-site-association`.

Annotated version (**upload the clean file**, because JSON has no comments):

```jsonc
{
  // Section for Universal Links (other sections exist: webcredentials, appclips).
  "applinks": {
    // One entry per app (or group of apps) that may open links of this domain.
    "details": [
      {
        // "<TeamID>.<bundle id>". TODO: replace TEAMID with your 10-character Team ID.
        "appIDs": ["TEAMID.com.example.tdeeplink"],
        // Which URL paths open the app; anything not matched stays in Safari.
        "components": [
          // /product/<anything> -> app.
          { "/": "/product/*" },
          // /profile/<anything> -> app.
          { "/": "/profile/*" }
        ]
      }
    ]
  }
}
```

Hosting requirements:

- HTTPS with a valid certificate, and **no redirects**.
- `Content-Type: application/json` is recommended. `hosting/firebase.json` already sets it.
- Without `?mode=developer`, devices fetch the file **through Apple's CDN**, which caches it for hours. Check what Apple currently sees:

```bash
# What Apple's CDN currently has for your domain:
curl -s "https://app-site-association.cdn-apple.com/a/v1/example.com"
```

### 3.4 On a real iPhone (developer mode)

Settings → **Developer** → turn on **Associated Domains Development**. This makes `?mode=developer` work. The Developer menu appears after you run an app from Xcode once.

---

## Testing

```bash
# Custom scheme: the app can be closed (cold start) or open (warm start):
scripts/test_deeplink.sh ios "tdeeplink://product/42?ref=email"
```

```bash
# Several Simulators booted? Pick one by UDID:
IOS_SIM=992B32E5-9A68-4A23-9262-149C5D00AD2E scripts/test_deeplink.sh ios "tdeeplink://profile/john"
```

```bash
# Universal Link (after step 3):
scripts/test_deeplink.sh ios "https://example.com/product/7"
```

To test like a real user, paste the link into **Notes** or **Messages** on the Simulator and tap it.

Links received show up in the Xcode console, or in `flutter run` output, as `Deep link received: ...`.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Custom scheme does nothing | Scheme missing or misspelled in `CFBundleURLSchemes`; app not reinstalled after editing Info.plist |
| Universal Link opens Safari | AASA not reachable or invalid, wrong Team ID or bundle id, capability not enabled, or Apple's CDN still has the old file (use `?mode=developer`) |
| Works once, then always opens Safari | The user tapped the domain name in the top-right banner ("open in Safari"), which iOS remembers. Long-press the link → **Open in "Tdeeplink"** to undo. |
| Link on a page of the same domain opens Safari | Expected: Universal Links don't trigger when navigating within the same domain in Safari. Tap it from another site or app. |
| Typed into Safari's address bar | Universal Links never trigger from typed URLs. Tap a link instead. |
| Screen opens twice | `FlutterDeepLinkingEnabled` isn't `false` |
| Device build: "Personal development teams do not support Associated Domains" | Needs a paid team (step 3.1) |
