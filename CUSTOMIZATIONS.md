# Focus iOS Customizations ("Web Viewer")

This documents all changes made on top of upstream Firefox Focus iOS to create the
"Web Viewer" app. These should be sufficient to recreate the fork on any version
of the upstream project.

---

## 1. Rebranding / Signing Identity

All changes are in the focus-ios subdirectory.

### Bundle Identifiers

Replace all `org.mozilla.ios.*` bundle identifiers with `me.whydontyoulove.ios.*`:

| Target               | Upstream                                        | Custom                                                |
|----------------------|-------------------------------------------------|-------------------------------------------------------|
| Focus (main app)     | `org.mozilla.ios.Focus`                         | `me.whydontyoulove.ios.Focus` (group prefix: `group.`) |
| Klar (main app)      | `org.mozilla.ios.Klar`                          | `me.whydontyoulove.ios.Klar` (group prefix: `group.`) |
| ContentBlocker       | `org.mozilla.ios.Focus.ContentBlocker`          | `me.whydontyoulove.ios.Focus.ContentBlocker`          |
| ShareExtension       | `org.mozilla.ios.Focus.ShareExtension`          | `me.whydontyoulove.ios.Focus.ShareExtension`          |
| FocusIntentExtension | `org.mozilla.ios.Focus.FocusIntentExtension`    | `me.whydontyoulove.ios.Focus.FocusIntentExtension`    |
| Widgets              | `org.mozilla.ios.Focus.Widgets`                 | `me.whydontyoulove.ios.Focus.Widgets`                 |
| RustMozillaAppServices | `org.mozilla.ios.RustMozillaAppServices`      | `me.whydontyoulove.ios.RustMozillaAppServices`        |
| (same pattern for Klar variants)                                                                                      |

### Development Team

Change `DEVELOPMENT_TEAM` from `43AQ936H96` (Mozilla) to your own team ID (was `NFZL2NT288`).

### Display Name

Change `DISPLAY_NAME` from `"Firefox Focus"` to `"Web Viewer"` in the FocusRelease
build configuration for the main Blockzilla target and ShareExtension.

### Entitlements

**Focus.entitlements:**
- Remove `com.apple.developer.siri` entitlement
- Change app group from `group.org.mozilla.ios.Focus` to `group.me.whydontyoulove.ios.Focus` (or your custom group)

**Klar.entitlements:**
- Remove `com.apple.developer.siri` entitlement
- Clear the app group array (or set your own)

**FocusIntentExtension.entitlements:**
- Change app group from `group.org.mozilla.ios.Focus` / `group.org.mozilla.ios.Klar`
  to your custom group

### Widgets/Info.plist

Remove the hardcoded `CFBundleShortVersionString` key (it gets set automatically).

---

## 2. App Icon

Replace the `AppIcon.dev.appiconset` in `Blockzilla/Assets.xcassets/` with a
single 1024x1024 icon using the modern Xcode format (universal, with optional
dark/tinted variants). Delete all the old per-size PNGs.

The `Contents.json` should use the single-size universal format:
```json
{
  "images" : [
    { "filename" : "icon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [{"appearance":"luminosity","value":"dark"}], "filename" : "icon-dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [{"appearance":"luminosity","value":"tinted"}], "filename" : "icon-tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

---

## 3. Launch Screen / Splash Screen De-branding

### LaunchScreen.storyboard (`Blockzilla/LaunchScreen.storyboard`)

- Remove the `img_focus_launchscreen` imageView and its constraints
- Set the background color to `systemBackgroundColor` (white/black) instead of the
  custom `LaunchBackground` named color

### SplashViewController (`Blockzilla/UIComponents/SplashViewController.swift`)

- Remove `logoImage` from the view (don't add it as subview, remove its constraints)
- Anchor the `authButton` to `view.topAnchor` instead of `logoImage.topAnchor`

### HomeViewController (`Blockzilla/HomeViewController.swift`)

- Always call `hideTextLogo()` and `hideTips()` in `updateViewConstraints()`
  (both portrait and landscape, both iPad and iPhone)

---

## 4. Disable Privacy Protection Screen

In `AppDelegate.swift`, comment out / remove the two calls to `showPrivacyProtectionWindow()`:
- In the `.willResignActive` case
- In the `.loggedout` case of the authentication callback

This prevents the purple overlay from appearing when the app goes to background.

---

## 5. UI Simplifications

### Always Show Toolset in URL Bar (`Blockzilla/BrowserViewController.swift`)

- Set `showsToolsetInURLBar` default value to `true` (was `false`)
- Replace the two conditional assignments of `showsToolsetInURLBar` (in
  `viewDidLoad` and `viewWillTransition`) with `showsToolsetInURLBar = true`

### Remove Bottom Toolbar Background Colors

- `BrowserViewController.swift`: Set `urlBarContainer.backgroundColor` to `.clear`
  instead of `.foundation` in `toggleURLBarBackground`
- `BrowserToolbar.swift`: Set toolbar background to `.clear` instead of `.foundation`
- `BrowserViewController.swift` (`addShortcutsBackgroundConstraints`): Remove the
  line setting `shortcutsBackground.backgroundColor`

### Disable URL Bar Text Interaction (`Blockzilla/UIComponents/URLBar/URLBar.swift`)

- Remove the `urlTextField.placeholder` assignment (no placeholder text)
- Empty out the `activateTextField()` method body (prevent user from focusing the
  URL text field)
- In the URL bar state machine, collapse `.browsing` and `.editing` cases into
  `.default` so the toolbar/buttons are always hidden

### Remove Tap-to-Focus-URLBar Behavior (`BrowserViewController.swift`)

In the `.expanded` scroll bar state handler for taps, remove the code that checks
tap Y position and calls `urlBar.activateTextField()`.

### Disable Review Prompts (`BrowserViewController.swift`)

Replace the body of `requestReviewIfNecessary()` with just `return`.

### Disable Tips (`Blockzilla/Pro Tips/TipManager.swift`)

- Make `tips` computed property return `[]` (empty array)
- Make `availableTips` computed property return `[]`

### Remove Menu Items

**MenuItemProvider.swift** (`Blockzilla/Menu/Protocol/MenuItemProvider.swift`):
- Remove `openInFireFoxItem` and `openInChromeItem` protocol requirements and implementations
- Remove `getShortcutsItem`, `addToShortcutsItem`, `removeFromShortcutsItem`
  protocol requirements and implementations

**BrowserViewController.swift** (in both `buildMenu` and `buildPhoneMenu`):
- Remove shortcuts menu items (`getShortcutsItem`)
- Remove "Open in Firefox" and "Open in Chrome" share items
- In the phone menu (`buildPhoneMenu`), also remove "Open in Default Browser"

---

## 6. Redirect X/Twitter Links to Echo App

### Info.plist (`Blockzilla/Info.plist`)

Add `echodotapp` to the `LSApplicationQueriesSchemes` array so iOS allows
checking/opening the Echo app.

### RequestHandler.swift (`Blockzilla/Lib/RequestHandler/RequestHandler.swift`)

Add a new case at the top of the `switch host` block in `handleRequest()` for
Twitter/X domains:

```swift
case "twitter.com", "www.twitter.com", "mobile.twitter.com",
     "x.com", "www.x.com", "mobile.x.com":
    // Build deep link: echodotapp://<path>?<query>#<fragment>
    var deepLinkString = "echodotapp://"
    let pathComponent = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if !pathComponent.isEmpty {
        deepLinkString += pathComponent
    }
    if let query = url.query, !query.isEmpty {
        deepLinkString += "?" + query
    }
    if let fragment = url.fragment, !fragment.isEmpty {
        deepLinkString += "#" + fragment
    }

    if let deepLinkURL = URL(string: deepLinkString, invalidCharacters: false) {
        if UIApplication.shared.canOpenURL(deepLinkURL) {
            UIApplication.shared.open(deepLinkURL, options: [:])
            return false
        } else {
            let alert = RequestHandler.makeAlert(
                title: String(format: UIConstants.strings.externalAppLinkWithAppName,
                              AppInfo.productName, "Echo"),
                action: UIConstants.strings.open,
                forURL: deepLinkURL)
            alertCallback(alert)
            return false
        }
    }
    return true
```
