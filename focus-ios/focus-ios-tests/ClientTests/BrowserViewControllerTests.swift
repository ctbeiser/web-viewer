/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
import Onboarding
import AppShortcuts

#if FOCUS
@testable import Firefox_Focus
#else
@testable import Firefox_Klar
#endif

class BrowserViewControllerTests: XCTestCase {
    private let mockUserDefaults = MockUserDefaults()

    private lazy var onboardingEventsHandler = OnboardingEventsHandlerV1(
        getShownTips: {
            return []
        }, setShownTips: { _ in
        }
    )

    private lazy var themeManager = ThemeManager()

    func testRequestReviewThreshold() {
        let bvc = BrowserViewController(
            shortcutManager: ShortcutsManager(),
            authenticationManager: AuthenticationManager(),
            onboardingEventsHandler: onboardingEventsHandler,
            gleanUsageReportingMetricsService: GleanUsageReportingMetricsService(),
            themeManager: themeManager
        )
        mockUserDefaults.clear()

        // Ensure initial threshold is set
        mockUserDefaults.set(1, forKey: UIConstants.strings.userDefaultsLaunchCountKey)
        bvc.requestReviewIfNecessary()
        XCTAssert(mockUserDefaults.integer(forKey: UIConstants.strings.userDefaultsLaunchThresholdKey) == 14)
        XCTAssert(mockUserDefaults.object(forKey: UIConstants.strings.userDefaultsLastReviewRequestDate) == nil)

        // Trigger first actual review request
        mockUserDefaults.set(15, forKey: UIConstants.strings.userDefaultsLaunchCountKey)
        bvc.requestReviewIfNecessary()

        // Check second threshold and date are set
        XCTAssert(mockUserDefaults.integer(forKey: UIConstants.strings.userDefaultsLaunchThresholdKey) == 64)
        guard let prevDate = mockUserDefaults.object(forKey: UIConstants.strings.userDefaultsLastReviewRequestDate) as? Date else {
            XCTFail("userDefaultsLastReviewRequestDate not date")
            return
        }

        let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: prevDate, to: Date()).day ?? -1
        XCTAssert(daysSinceLastRequest == 0)

        // Trigger second review request with prevDate < 90 days (i.e. launch threshold should remain the same due to early return)
        mockUserDefaults.set(65, forKey: UIConstants.strings.userDefaultsLaunchCountKey)
        bvc.requestReviewIfNecessary()
        XCTAssert(mockUserDefaults.integer(forKey: UIConstants.strings.userDefaultsLaunchThresholdKey) == 64)

        // Trigger actual second review
        mockUserDefaults.set(nil, forKey: UIConstants.strings.userDefaultsLastReviewRequestDate)
        bvc.requestReviewIfNecessary()
        XCTAssert(mockUserDefaults.integer(forKey: UIConstants.strings.userDefaultsLaunchThresholdKey) == 114)
    }

    func testArchiveIsSubmissionURL_buildsExpectedURL() throws {
        let sourceURL = try XCTUnwrap(URL(string: "https://example.com/article?id=42&lang=en"))
        let archiveURL = try XCTUnwrap(BrowserViewController.archiveIsSubmissionURL(for: sourceURL))
        let components = try XCTUnwrap(URLComponents(url: archiveURL, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "archive.is")
        XCTAssertEqual(components.path, "/submit/")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "url", value: sourceURL.absoluteString)])
    }

    func testPasskeyAvailabilityUserScriptDisablesWebAuthnSignals() {
        let source = PasskeyAvailabilityUserScript.source

        XCTAssertTrue(source.contains("PublicKeyCredential"))
        XCTAssertTrue(source.contains("isUserVerifyingPlatformAuthenticatorAvailable"))
        XCTAssertTrue(source.contains("isConditionalMediationAvailable"))
        XCTAssertTrue(source.contains("navigator.credentials"))
        XCTAssertTrue(source.contains("options.publicKey"))
        XCTAssertTrue(source.contains("NotSupportedError"))
    }

    func testPasskeyAvailabilityInstallsUserScriptWithoutBrowserEntitlement() {
        XCTAssertTrue(PasskeyAvailability.shouldInstallUserScript(hasBrowserPublicKeyCredentialEntitlement: false))
    }

    func testPasskeyAvailabilityDoesNotInstallUserScriptWithBrowserEntitlement() {
        XCTAssertFalse(PasskeyAvailability.shouldInstallUserScript(hasBrowserPublicKeyCredentialEntitlement: true))
    }

    func testSignedEntitlementsReaderReadsBrowserEntitlementFromCodeSignature() throws {
        let codeSignature = try makeCodeSignature(entitlements: [
            PasskeyAvailability.browserPublicKeyCredentialEntitlement: true
        ])
        let entitlements = try XCTUnwrap(SignedEntitlementsReader.entitlements(inCodeSignature: codeSignature))

        XCTAssertTrue(PasskeyAvailability.containsBrowserPublicKeyCredentialEntitlement(in: entitlements))
    }

    private func makeCodeSignature(entitlements: [String: Any]) throws -> Data {
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: entitlements,
            format: .xml,
            options: 0
        )
        let blobOffset = UInt32(20)
        let blobLength = UInt32(8 + plistData.count)

        var data = Data()
        data.appendBigEndianUInt32(0xfade0cc0)
        data.appendBigEndianUInt32(blobOffset + blobLength)
        data.appendBigEndianUInt32(1)
        data.appendBigEndianUInt32(5)
        data.appendBigEndianUInt32(blobOffset)
        data.appendBigEndianUInt32(0xfade7171)
        data.appendBigEndianUInt32(blobLength)
        data.append(plistData)
        return data
    }
}

private class MockUserDefaults: UserDefaults {
    func clear() {
        removeObject(forKey: BrowserViewController.userDefaultsTrackersBlockedKey)
        removeObject(forKey: UIConstants.strings.userDefaultsLastReviewRequestDate)
        removeObject(forKey: UIConstants.strings.userDefaultsLaunchCountKey)
        removeObject(forKey: UIConstants.strings.userDefaultsLaunchThresholdKey)
    }
}

private extension Data {
    mutating func appendBigEndianUInt32(_ value: UInt32) {
        append(contentsOf: [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ])
    }
}
