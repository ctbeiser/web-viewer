/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

private let internalSchemes: Set<String> = ["http", "https", "ftp", "file", "about", "javascript", "data"]

class RequestHandler {
    func handle(request: URLRequest, alertCallback: (UIAlertController) -> Void) -> Bool {
        guard let url = request.url,
              let scheme = request.url?.scheme?.lowercased() else {
            return false
        }

        // If the URL isn't a scheme the browser can open, let the system handle it if
        // it's a scheme we want to support.
        guard internalSchemes.contains(scheme) else {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return false
            }

            let title = components.path

            switch scheme {
            case "tel":
                // Don't present our dialog as the system presents its own
                UIApplication.shared.open(url, options: [:])
            case "facetime", "facetime-audio":
                let alert = RequestHandler.makeAlert(title: title, action: "FaceTime", forURL: url)
                alertCallback(alert)
            case "mailto":
                let alert = RequestHandler.makeAlert(title: title, action: UIConstants.strings.externalLinkEmail, forURL: url)
                alertCallback(alert)
            default:
                let openAction = UIAlertAction(title: UIConstants.strings.open, style: .default) { _ in
                    UIApplication.shared.open(url, options: [:])
                }

                let cancelAction = UIAlertAction(title: UIConstants.strings.externalLinkCancel, style: .cancel) { _ in
                }

                let alert = UIAlertController(title: String(format: UIConstants.strings.externalAppLink, AppInfo.productName),
                                              message: nil,
                                              preferredStyle: .alert)

                alert.addAction(cancelAction)
                alert.addAction(openAction)
                alert.preferredAction = openAction
                alertCallback(alert)
            }

            return false
        }

        guard scheme == "http" || scheme == "https",
              let host = url.host?.lowercased() else {
            return true
        }

        switch host {
        case "twitter.com", "www.twitter.com", "mobile.twitter.com", "x.com", "www.x.com", "mobile.x.com":
            // Build deep link to Echo: echodotapp://<everything after .com/>
            // Extract path + query + fragment from the original URL
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
                // Open directly if possible, otherwise fall back to in-app navigation
                if UIApplication.shared.canOpenURL(deepLinkURL) {
                    UIApplication.shared.open(deepLinkURL, options: [:])
                    return false
                } else {
                    // If iOS requires confirmation or the scheme isn't allowed, present confirmation to open Echo
                    let alert = RequestHandler.makeAlert(title: String(format: UIConstants.strings.externalAppLinkWithAppName, AppInfo.productName, "Echo"), action: UIConstants.strings.open, forURL: deepLinkURL)
                    alertCallback(alert)
                    return false
                }
            }
            return true
        case "maps.apple.com":
            let alert = RequestHandler.makeAlert(title: String(format: UIConstants.strings.externalAppLinkWithAppName, AppInfo.productName, "Maps"), action: UIConstants.strings.open, forURL: url)
            alertCallback(alert)
            return false
        case "itunes.apple.com":
            let alert = RequestHandler.makeAlert(title: String(format: UIConstants.strings.externalAppLinkWithAppName, AppInfo.productName, "App Store"), action: UIConstants.strings.open, forURL: url)
            alertCallback(alert)
            return false
        default:
            return true
        }
    }

    private static func makeAlert(title: String, action: String, forURL url: URL) -> UIAlertController {
        let openAction = UIAlertAction(title: action, style: .default) { _ in
            UIApplication.shared.open(url, options: [:])
        }
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: UIConstants.strings.externalLinkCancel, style: .cancel, handler: nil))
        alert.addAction(openAction)
        alert.preferredAction = openAction
        return alert
    }
}
