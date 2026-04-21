/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import WebKit

final class WebsiteDarkModeController: NSObject {
    private enum UX {
        static let resourceName = "NightModeAllFramesAtDocumentStart"
        static let scriptHandlerName = "NightMode"
    }

    private static let contentWorld = WKContentWorld.world(name: UX.scriptHandlerName)

    private var isEnabled = false
    private lazy var userScriptSource: String? = {
        guard let url = Bundle.main.url(forResource: UX.resourceName, withExtension: "js") else {
            assertionFailure("Missing \(UX.resourceName).js")
            return nil
        }

        return try? String(contentsOf: url)
    }()

    func configure(webView: WKWebView, isEnabled: Bool) {
        self.isEnabled = isEnabled
        let userContentController = webView.configuration.userContentController
        userContentController.add(self, contentWorld: Self.contentWorld, name: UX.scriptHandlerName)
        addUserScript(to: userContentController)
        apply(to: webView)
    }

    func reinstallUserScript(in webView: WKWebView) {
        addUserScript(to: webView.configuration.userContentController)
        apply(to: webView)
    }

    func setEnabled(_ isEnabled: Bool, in webView: WKWebView?) {
        self.isEnabled = isEnabled
        guard let webView else { return }
        apply(to: webView)
    }

    private func addUserScript(to userContentController: WKUserContentController) {
        guard let userScriptSource else { return }

        let userScript = WKUserScript(
            source: userScriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: Self.contentWorld
        )
        userContentController.addUserScript(userScript)
    }

    private func apply(to webView: WKWebView) {
        webView.isOpaque = !isEnabled
        webView.underPageBackgroundColor = isEnabled ? .black : nil
        webView.scrollView.indicatorStyle = isEnabled ? .white : .default
        webView.evaluateJavaScript(
            "window.__firefox__.NightMode.setEnabled(\(isEnabled))",
            in: nil,
            in: Self.contentWorld
        ) { _ in }
    }
}

extension WebsiteDarkModeController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == UX.scriptHandlerName, let webView = message.frameInfo.webView else { return }
        apply(to: webView)
    }
}
