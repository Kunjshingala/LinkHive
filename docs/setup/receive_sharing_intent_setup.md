# Receive Sharing Intent Setup

This document explains how LinkHive integrates with the OS share sheet on Android and iOS using the [`receive_sharing_intent`](https://pub.dev/packages/receive_sharing_intent) package. When a user shares a URL from any app (browser, social media, etc.), LinkHive appears as a share target and captures the URL into the Add Link screen.

---

## How It Works

### High-Level Flow

```
User taps "Share" in any app
        |
        v
OS shows share sheet with LinkHive listed
        |
        v
User selects LinkHive
        |
        v
[Platform-specific handoff — see below]
        |
        v
Flutter receives the shared URL via receive_sharing_intent
        |
        v
App navigates to AddLinkScreen with URL pre-filled
```

### Flutter Side (Both Platforms)

The shared intent is handled in `lib/core/services/receive_shared_intent.dart`:

- **`ReceiveSharedIntent.initialize()`** — called at app startup, sets up two listeners:
  - **Foreground listener** (`getMediaStream()`) — fires when a URL is shared while the app is already running.
  - **Cold-start listener** (`getInitialMedia()`) — fires when the app is launched from a share action.
- Both listeners extract the URL and call `router.pushNamed(MyRouteName.addLink, extra: url)` to navigate to the Add Link screen.

---

## Android Setup

Android uses **Intent Filters** to register the app as a share target. This is purely declarative — no extra targets or extensions needed.

### How It Works on Android

```
User taps Share in Chrome
        |
        v
Android checks all apps' manifest for matching <intent-filter>
        |
        v
LinkHive's MainActivity matches ACTION_SEND + text/*
        |
        v
Android delivers the Intent to LinkHive's Flutter engine
        |
        v
receive_sharing_intent plugin reads the Intent extras
        |
        v
Plugin forwards the shared text/URL to Dart via platform channel
```

### Configuration

**File:** `android/app/src/main/AndroidManifest.xml`

Inside the `<activity>` tag for `MainActivity`, add these intent filters:

```xml
<!-- Accept single text shares (covers URLs shared as text) -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/*" />
</intent-filter>

<!-- Accept single plain text shares -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>

<!-- Accept multiple plain text shares -->
<intent-filter>
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>
```

### What Each Part Means

| Element | Purpose |
|---------|---------|
| `android.intent.action.SEND` | Tells Android this app can receive shared content |
| `android.intent.category.DEFAULT` | Required for implicit intents (share sheet uses implicit intents) |
| `android:mimeType="text/*"` | Accepts any text content (URLs, plain text, etc.) |
| `android.intent.action.SEND_MULTIPLE` | Accepts multiple items shared at once |

That's it for Android — no App Groups, no extensions, no extra targets.

---

## iOS Setup

iOS requires significantly more setup because of Apple's sandboxing model. Apps can't directly receive data from other apps — you need a **Share Extension** (a separate mini-app) and **App Groups** (shared storage) to bridge the gap.

### How It Works on iOS

```
User taps Share in Safari
        |
        v
iOS loads the ShareExtension binary (separate process)
        |
        v
ShareExtension receives the URL via NSExtensionContext
        |
        v
RSIShareViewController saves URL to App Groups (UserDefaults)
        |
        v
Extension opens main app via custom URL scheme:
  "ShareMedia-com.link.hive:share"
        |
        v
Main app launches (or comes to foreground)
        |
        v
receive_sharing_intent plugin reads URL from App Groups (UserDefaults)
        |
        v
Plugin forwards URL to Dart via platform channel
```

### Key Concepts

**Share Extension:** A separate compiled binary that iOS loads when the user selects LinkHive from the share sheet. It runs in its own process with limited memory and APIs. It does NOT have access to the main app's data directly.

**App Groups:** A shared storage container (UserDefaults + file system) that both the main app and the Share Extension can read/write to. This is how the extension passes the shared URL to the main app.

**Custom URL Scheme:** After saving the URL to App Groups, the extension needs to open the main app. It does this by calling `openURL("ShareMedia-com.link.hive:share")`, which iOS routes to the main app because of the registered URL scheme.

### Step 1: Create Share Extension Target (Xcode)

This must be done in Xcode — it cannot be done from the command line or Android Studio.

1. Open `ios/Runner.xcworkspace` in Xcode
2. **File > New > Target > Share Extension**
3. Product Name: `ShareExtension`
4. Language: **Swift**
5. Click **Finish**
6. When prompted "Activate scheme?" > Click **Activate**
7. Set Bundle Identifier to: `com.link.hive.ShareExtension`
8. Set Minimum Deployments to: `16.0`

This creates `ios/ShareExtension/` with these files:
- `ShareViewController.swift` — entry point
- `Info.plist` — extension configuration
- `ShareExtension.entitlements` — capabilities

### Step 2: Configure App Groups (Xcode)

Both the main app and extension need the same App Group to share data.

**For the Runner target:**
1. Select `Runner` target > Signing & Capabilities
2. Click **+ Capability** > **App Groups**
3. Add group: `group.com.link.hive`

**For the ShareExtension target:**
1. Select `ShareExtension` target > Signing & Capabilities
2. Click **+ Capability** > **App Groups**
3. Add group: `group.com.link.hive` (same group ID)

**Verification:** Both `ios/Runner/Runner.entitlements` and `ios/ShareExtension/ShareExtension.entitlements` should contain:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.link.hive</string>
</array>
```

### Step 3: ShareExtension Swift Files

The Share Extension needs three Swift files. These are included directly (not via CocoaPods) because the full `receive_sharing_intent` pod contains Flutter plugin code that uses app-only APIs (`addApplicationDelegate`) which are forbidden in app extensions.

**`ios/ShareExtension/ShareViewController.swift`** — Entry point:

```swift
import UIKit

class ShareViewController: RSIShareViewController {
    // RSIShareViewController handles everything:
    // - Receives shared URLs/text from the share sheet
    // - Saves them to App Groups shared storage
    // - Redirects back to the main app
}
```

**`ios/ShareExtension/RSIShareViewController.swift`** — Copied from the `receive_sharing_intent` plugin's `ios/Classes/` directory. This is the base class that:
- Reads the shared content from `NSExtensionContext`
- Saves it to `UserDefaults` in the App Group container
- Redirects to the main app via the custom URL scheme

**`ios/ShareExtension/SharedMediaModels.swift`** — Constants and models extracted from the plugin:
- `kSchemePrefix` = `"ShareMedia"` — URL scheme prefix
- `kUserDefaultsKey` = `"ShareKey"` — key for shared data in UserDefaults
- `kAppGroupIdKey` = `"AppGroupId"` — key to read group ID from Info.plist
- `SharedMediaFile` — model for shared content
- `SharedMediaType` — enum for content types (url, text, image, etc.)

### Step 4: Share Extension Info.plist

**File:** `ios/ShareExtension/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AppGroupId</key>
    <string>group.com.link.hive</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
                <integer>1</integer>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
            </dict>
        </dict>
        <key>NSExtensionMainStoryboard</key>
        <string>MainInterface</string>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
    </dict>
</dict>
</plist>
```

| Key | Purpose |
|-----|---------|
| `AppGroupId` | Tells `RSIShareViewController` which App Group to write shared data to |
| `NSExtensionActivationSupportsWebURLWithMaxCount: 1` | Extension appears when sharing a single URL |
| `NSExtensionActivationSupportsText: true` | Extension appears when sharing text (some apps share URLs as plain text) |
| `NSExtensionPointIdentifier: com.apple.share-services` | Registers this as a Share Extension (vs. Action Extension, etc.) |

### Step 5: Main App Info.plist

**File:** `ios/Runner/Info.plist`

Add the App Group ID so the plugin knows where to read shared data:

```xml
<key>AppGroupId</key>
<string>group.com.link.hive</string>
```

Add the custom URL scheme so the extension can redirect back to the main app:

```xml
<key>CFBundleURLTypes</key>
<array>
    <!-- ... existing Google Sign-In URL scheme ... -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>ShareMedia-com.link.hive</string>
        </array>
    </dict>
</array>
```

The URL scheme format is `ShareMedia-<bundle_id>`. The extension constructs this dynamically by reading its own bundle ID and stripping the last component (`.ShareExtension`).

### Step 6: Podfile

**File:** `ios/Podfile`

Add an empty target for ShareExtension (no pods needed since Swift files are included directly):

```ruby
target 'ShareExtension' do
  use_frameworks!
  # No pods needed — Swift source files are included directly in the target
end
```

**Xcode 26 compatibility note:** If you're using Xcode 26+, you may need this workaround at the top of the Podfile because CocoaPods doesn't recognize project object version 70 yet:

```ruby
require 'xcodeproj'
unless Xcodeproj::Constants::COMPATIBILITY_VERSION_BY_OBJECT_VERSION.key?(70)
  map = Xcodeproj::Constants::COMPATIBILITY_VERSION_BY_OBJECT_VERSION.dup
  map[70] = 'Xcode 16.0'
  Xcodeproj::Constants.send(:remove_const, :COMPATIBILITY_VERSION_BY_OBJECT_VERSION)
  Xcodeproj::Constants.const_set(:COMPATIBILITY_VERSION_BY_OBJECT_VERSION, map.freeze)
end
```

### Step 7: Build Phase Order Fix

After adding the Share Extension target, Xcode may place "Embed Foundation Extensions" after "Thin Binary" in the Runner target's build phases. This causes a build cycle error.

**Fix:** In Xcode, select Runner target > Build Phases, and drag "Embed Foundation Extensions" **above** "Thin Binary".

Or verify in `ios/Runner.xcodeproj/project.pbxproj` that the order is:

```
Embed Frameworks
Embed Foundation Extensions    <-- must be BEFORE Thin Binary
Thin Binary
[CP] Embed Pods Frameworks
[CP] Copy Pods Resources
```

### Step 8: Install & Verify

```bash
# Install pods
cd ios && pod install && cd ..

# Build for simulator
fvm flutter build ios --simulator --no-codesign

# Run the app
fvm flutter run --dart-define-from-file=firebase_config.json
```

---

## Testing

### Android
1. Run the app on an Android device/emulator
2. Open Chrome and navigate to any URL
3. Tap the Share button
4. Select **LinkHive** from the share sheet
5. The app opens with the URL pre-filled on the Add Link screen

### iOS (Simulator)
1. Run the app on the iOS Simulator
2. Open Safari and navigate to any URL:
   ```bash
   xcrun simctl openurl booted "https://example.com"
   ```
3. Tap the Share button in Safari
4. Select **LinkHive** from the share sheet
5. The extension saves the URL and redirects to the main app
6. The Add Link screen opens with the URL pre-filled

### iOS (Physical Device)
Same flow as simulator, but you need:
- A valid Apple Developer account for code signing
- App Groups capability enabled in your provisioning profile
- Both Runner and ShareExtension must use the same team/signing identity

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| LinkHive doesn't appear in Android share sheet | Check that intent filters are in `AndroidManifest.xml` inside the `<activity>` tag |
| LinkHive doesn't appear in iOS share sheet | Verify the Share Extension target exists and builds successfully |
| iOS extension crashes | Check that `AppGroupId` matches in both `Info.plist` files and entitlements |
| URL not received after sharing on iOS | Verify the `ShareMedia-com.link.hive` URL scheme is in Runner's `Info.plist` |
| `addApplicationDelegate is unavailable` build error | The ShareExtension is linking the full plugin pod — use direct Swift files instead |
| Xcode build cycle error | Move "Embed Foundation Extensions" before "Thin Binary" in Runner build phases |
| `pod install` fails with object version 70 | Add the Xcode 26 compatibility workaround to the Podfile |

---

## File Reference

### Android
| File | Purpose |
|------|---------|
| `android/app/src/main/AndroidManifest.xml` | Intent filters for share targets |

### iOS
| File | Purpose |
|------|---------|
| `ios/ShareExtension/ShareViewController.swift` | Extension entry point |
| `ios/ShareExtension/RSIShareViewController.swift` | Base class — handles receiving, saving, and redirecting |
| `ios/ShareExtension/SharedMediaModels.swift` | Constants and models for shared data |
| `ios/ShareExtension/Info.plist` | Extension config — accepted content types, App Group ID |
| `ios/ShareExtension/ShareExtension.entitlements` | App Groups capability |
| `ios/Runner/Runner.entitlements` | App Groups capability (main app) |
| `ios/Runner/Info.plist` | App Group ID + custom URL scheme |
| `ios/Podfile` | ShareExtension target declaration |

### Flutter
| File | Purpose |
|------|---------|
| `lib/core/services/receive_shared_intent.dart` | Dart listener for shared URLs — navigates to AddLinkScreen |
