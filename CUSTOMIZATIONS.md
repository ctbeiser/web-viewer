# Focus iOS Customizations ("Web Viewer")

This documents all changes made on top of upstream Firefox Focus iOS to create the
"Web Viewer" app. These should be sufficient to recreate the fork on any version
of the upstream project.

**Maintenance rule:** every Web Viewer customization, fix, or behavior change
must be documented in this file when the change is made. Future agents should
read this file before editing `focus-ios` and keep it current.

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

Change the Blockzilla app target `PRODUCT_NAME` from `"Firefox Focus"` to
`"Web Viewer"` in the Focus app build configurations so `CFBundleName` and the
built app name are consistent. Also update shared Xcode schemes under
`Blockzilla.xcodeproj/xcshareddata/xcschemes/` so every `BuildableName` that
points at the Blockzilla app uses `Web Viewer.app` instead of
`Firefox Focus.app`.

Set `INFOPLIST_KEY_LSApplicationCategoryType` to
`public.app-category.utilities` for the app build configurations.

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
Set the WidgetsExtension target `MARKETING_VERSION` to `$(APP_VERSION)` in all
build configurations so the generated extension plist version matches the
containing app version.

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

---

## 7. URL Bar Visual Behavior

### Liquid Glass / Transparent URL Bar (`Blockzilla/UIComponents/URLBar/URLBar.swift`)

- Make `urlBarBorderView.backgroundColor` clear and keep URL bar state border
  colors clear.
- Replace the URL bar background with `UIGlassEffect` inside a
  `UIVisualEffectView` on iOS 26 and newer.
- On older iOS versions, keep the URL bar background clear.
- When the background is a `UIVisualEffectView`, add `textAndLockContainer` to
  the effect view's `contentView`.

### Hide Tracking Protection UI From URL Bar

In `URLBar.swift`:
- Initialize `shieldIcon.isHidden = true`
- Animate the shield icon hidden in all URL bar states
- Keep shield icon alpha at `0` when the URL bar collapses

In `BrowserViewController.swift`:
- Make `controller(for route:)` return `nil` to suppress onboarding tooltips and
  tracking protection popups.

### Forced Dark Mode URL Bar Toggle

When system dark mode activates the app's forced dark-mode override, show a moon
button on the left side of the URL bar. Tapping it disables that app override
for the current site and changes the icon to a slashed moon; tapping again
re-enables the override. Sites with native dark themes can still render dark
through their own CSS. Navigating to a different base domain or returning to
system light mode clears the temporary override. Use outlined SF Symbols
(`moon` when enabled, `sun.max` when disabled) and otherwise mirror the
surrounding URL bar icon buttons, including the same 40pt tap target.

### Tap URL Bar to Share (`Blockzilla/BrowserViewController.swift`)

In `urlBarDidPressScrollTop(_:tap:)`, replace the expanded-state scroll-to-top
behavior with share-sheet presentation for the current URL:
- Build `OpenUtils(url:webViewController:)`
- Call `showSharePage(for:sender:)` with the URL bar as the sender
- Keep the collapsed-state behavior that shows toolbars

---

## 8. Accent Styling / Progress Bar

### Accent Colors

Update both accent color assets to orange:
- `BlockzillaPackage/Sources/DesignSystem/Colors.xcassets/Accent.colorset/Contents.json`
- `BlockzillaPackage/Sources/Onboarding/DesignSystem/Colors.xcassets/Accent.colorset/Contents.json`

Use:
- Light: `#FF9500`
- Dark: `#FFB340`

### Loading Progress Bar (`Blockzilla/UIComponents/GradientProgressBar.swift`)

Replace the three-color gradient with the app accent color for every gradient
stop:

```swift
static let gradientColors = [
    UIColor.accent.cgColor,
    UIColor.accent.cgColor,
    UIColor.accent.cgColor
]
```

---

## 9. Archive.is URL Bar Button

### URL Bar Button (`Blockzilla/UIComponents/URLBar/URLBar.swift`)

Add an `archiveButton` next to the stop/reload button:
- Use `UIImage(systemName: "archivebox")`
- Use `UIConstants.strings.browserArchivePage` for the accessibility label
- Use accessibility identifier `URLBar.archiveButton`
- Hide it by default and animate it with the page action icons
- Add it to `textAndLockContainer`
- Constrain it before `stopReloadButton` with
  `UIConstants.layout.urlBarPageActionSpacing`
- Include it in collapsed URL bar alpha updates

Add `urlBarPageActionSpacing = 4` to `UIConstants.layout`.

### URL Bar View Model

Add `case archiveButtonTap` to `URLViewAction` in
`Blockzilla/UIComponents/URLBar/URLBarViewModel.swift`, and publish that action
from the archive button tap handler.

### Browser Action (`Blockzilla/BrowserViewController.swift`)

Handle `.archiveButtonTap` in `bindUrlBarViewModel()` by opening the current URL
through Archive.is.

Add:

```swift
static func archiveIsSubmissionURL(for url: URL) -> URL? {
    var components = URLComponents(string: "https://archive.is/submit/")
    components?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
    return components?.url
}

func openInArchiveIs(url: URL) {
    guard let archiveURL = Self.archiveIsSubmissionURL(for: url) else { return }

    submit(url: archiveURL, source: .action)
    GleanMetrics.BrowserMenu.browserMenuAction.record(
        GleanMetrics.BrowserMenu.BrowserMenuActionExtra(item: "archive_is")
    )
}
```

Add a client test in `focus-ios-tests/ClientTests/BrowserViewControllerTests.swift`
that verifies the generated Archive.is submission URL.

---

## 10. Website Dark Mode

### Dark Reader Script Resource

Add `Blockzilla/NightModeAllFramesAtDocumentStart.js` to the Blockzilla app
resources. This bundled script defines `window.__firefox__.NightMode` and exposes
`setEnabled`.

### Controller (`Blockzilla/Modules/WebView/WebsiteDarkModeController.swift`)

Add `WebsiteDarkModeController` to manage page dark mode:
- Load `NightModeAllFramesAtDocumentStart.js` from the app bundle
- Inject it as a `WKUserScript` at `.atDocumentStart`
- Inject into all frames (`forMainFrameOnly: false`)
- Use a dedicated `WKContentWorld` named `NightMode`
- Register a `WKScriptMessageHandler` named `NightMode`
- Apply the enabled state by evaluating
  `window.__firefox__.NightMode.setEnabled(...)`
- When enabled, set the web view opaque flag off, under-page background to black,
  and scroll indicators to white

### Web View Integration (`Blockzilla/Modules/WebView/LegacyWebViewController.swift`)

- Add a `WebsiteDarkModeController` instance
- Track `isWebsiteDarkModeEnabled`
- Configure website dark mode after the `WKWebView` is created
- Expose `setWebsiteDarkModeEnabled(_:)` so the browser controller can update it

### Browser Trait Integration (`Blockzilla/BrowserViewController.swift`)

- Add `syncForcedDarkModeOverride()`
- Call it during setup and trait changes
- Enable the forced dark-mode override when `traitCollection.userInterfaceStyle == .dark`

### Package Pins

Keep the Focus SwiftPM resolved pins updated with the dark mode work:
- Kingfisher `8.8.1`
- SwiftyBeaver `2.1.1`

---

## 11. SwiftLint Build Behavior

### SwiftLint Baseline

The Focus Xcode project's `Run Swiftlint` build phase should invoke
`bin/run_swiftlint.sh`.

`focus-ios/bin/run_swiftlint.sh` should:
- Add `/opt/homebrew/bin` to `PATH` on Apple Silicon
- Exit successfully with a warning if `swiftlint` is unavailable
- Limit linting to modified, staged, and untracked Swift files under `focus-ios`
- Run from the repo root with the Focus config at `focus-ios/.swiftlint.yml`
- Use `.swiftlint-baseline.json` when present
- Pass `--force-exclude`
- Skip linting when no modified Swift files exist under `focus-ios`

The project-level build phase previously embedded this logic directly; keep the
logic in the script instead.

---

## 12. Faster Focus Build Scripts

### Nimbus Codegen

Add `focus-ios/bin/run_nimbus_codegen.sh` and make the Xcode "Nimbus Feature
Manifest Generator Script" call it instead of calling `nimbus-fml.sh` directly.

The wrapper should:
- Generate files into a temporary directory
- Sync only changed generated files into `Blockzilla/Generated`
- Avoid rewriting unchanged generated files

Update the Xcode build phase inputs to include:
- `$(SOURCE_ROOT)/bin/nimbus-fml.sh`
- `$(SOURCE_ROOT)/bin/nimbus-fml-configuration.sh`
- `$(SOURCE_ROOT)/bin/run_nimbus_codegen.sh`
- `$(SOURCE_ROOT)/nimbus.fml.yaml`

Remove `alwaysOutOfDate` from this build phase so Xcode can skip it when inputs
and outputs are current.

### Wordmark Copy Script

Add `focus-ios/bin/copy_wordmark.sh` and make the Xcode "Run Script (Copy
Wordmark)" phase call it.

The script should:
- Use `set -euo pipefail`
- Copy Focus or Klar wordmark assets based on `PRODUCT_NAME`
- Compare with `cmp -s` before copying so unchanged assets are not rewritten

Update the build phase with explicit input and output paths for the source
wordmarks, destination launchscreen wordmarks, and script file. Remove
`alwaysOutOfDate` from the phase.

### Glean SDK Generator (`focus-ios/bin/sdk_generator.sh`)

Update the Glean generator script to reduce unnecessary work:
- Use `set -euo pipefail`
- Reuse the existing `.venv`
- Install or upgrade `glean_parser` only when the requested major/minor version
  is missing
- Generate Swift output into a temporary directory
- Sync only changed generated files into the final output directory

---

## 13. Focus Package Resolution

When Xcode package pins are refreshed for Focus, keep
`focus-ios/Blockzilla.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
checked in with the Focus project. Recent customization work expects:
- Kingfisher `8.8.1`
- SwiftyBeaver `2.1.1`

---

## 14. Inline PDF Viewing and Attachment Downloads

### Web View Response Policy (`Blockzilla/Modules/WebView/LegacyWebViewController.swift`)

Focus previously cancelled binary (`application/octet-stream` or missing MIME
type) and `Content-Disposition: attachment` responses. In Web Viewer, convert
non-PDF binary/attachment responses into `WKDownload` instead of cancelling so
signed URLs keep their original request, cookies, redirects, and query tokens.

PDF responses should remain viewable in the browser UI. Before deciding to
download a response, allow it inline when any of these are true:
- `response.mimeType` is `application/pdf`
- `response.url?.pathExtension` is `pdf`
- `response.suggestedFilename` ends in `.pdf`
- the `Content-Disposition` header contains `.pdf`

For non-PDF downloads:
- Return `.download` from `decidePolicyFor navigationResponse`
- Set the `WKDownload.delegate` in both `didBecome download` callbacks
- Write downloads into a unique directory under `temporaryDirectory`
- Present the completed file with `UIActivityViewController`
- Remove the temporary download directory after the activity controller finishes
- Show a simple localized "Download Failed" alert if the download fails

---

## 15. Preserve Login Sessions

Web Viewer keeps site login state when the user taps erase or relaunches the app:
- `LegacyWebViewController.swift`: use `WKWebsiteDataStore.default()` instead of
  `WKWebsiteDataStore.nonPersistent()` so cookies and site storage persist across
  webview resets. It also sets `WebKitLocalStorageEnabledPreferenceKey` to `true`
  before creating the webview.
- `WebCacheUtils.swift`: keep clearing cache files and in-memory history, but do
  not delete cookies, localStorage, IndexedDB, WebSQL, or other login-bearing
  website storage.
- Update English erase/onboarding copy so the UI no longer says cookies or
  passwords are cleared.

---

## 16. Conditionally Disable Passkey Advertising in WKWebView

### WebAuthn / Passkeys (`Blockzilla/Modules/WebView/LegacyWebViewController.swift`)

The custom app usually is not signed with Apple's managed browser passkey
entitlement and does not have `webcredentials:` associated domains for arbitrary
relying parties, so WKWebView passkey calls can be advertised to pages but fail
in practice.

- Check the signed
  `com.apple.developer.web-browser.public-key-credential` entitlement at runtime
- If the entitlement is present, leave WebKit's native passkey APIs untouched
- If the entitlement is missing, add a document-start user script that hides
  `window.PublicKeyCredential`
- Make WebAuthn availability probes resolve `false`
- Make `navigator.credentials.create/get` reject `publicKey` requests with
  `NotSupportedError`
- Reinstall this script whenever the web view's user scripts are rebuilt after
  disabling tracking protection
