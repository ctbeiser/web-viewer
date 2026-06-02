/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

enum PasskeyAvailabilityUserScript {
    static let source = """
    (() => {
        const unavailable = () => Promise.resolve(false);
        const reject = () => Promise.reject(
            new DOMException("Passkeys are not available in this app.", "NotSupportedError")
        );
        const define = (target, property, descriptor) => {
            try {
                Object.defineProperty(target, property, descriptor);
            } catch (_) {}
        };

        if (window.PublicKeyCredential) {
            define(window.PublicKeyCredential, "isUserVerifyingPlatformAuthenticatorAvailable", {
                configurable: true,
                writable: true,
                value: unavailable
            });
            define(window.PublicKeyCredential, "isConditionalMediationAvailable", {
                configurable: true,
                writable: true,
                value: unavailable
            });
        }

        define(window, "PublicKeyCredential", {
            configurable: true,
            writable: true,
            value: undefined
        });

        if (!navigator.credentials) {
            return;
        }

        const credentials = navigator.credentials;
        const prototype = Object.getPrototypeOf(credentials);
        const installMethod = (property) => {
            const original = credentials[property] ? credentials[property].bind(credentials) : undefined;
            const wrapped = (options) => {
                if (options && options.publicKey) {
                    return reject();
                }
                if (original) {
                    return original(options);
                }
                return Promise.reject(
                    new DOMException("Credential method is not available.", "NotSupportedError")
                );
            };

            define(credentials, property, {
                configurable: true,
                writable: true,
                value: wrapped
            });
            define(prototype, property, {
                configurable: true,
                writable: true,
                value: wrapped
            });
        };

        installMethod("create");
        installMethod("get");
    })();
    """
}

enum PasskeyAvailability {
    static let browserPublicKeyCredentialEntitlement = "com.apple.developer.web-browser.public-key-credential"

    static func shouldInstallUserScript(
        hasBrowserPublicKeyCredentialEntitlement: Bool = signedPasskeyEntitlementPresent
    ) -> Bool {
        return !hasBrowserPublicKeyCredentialEntitlement
    }

    static func containsBrowserPublicKeyCredentialEntitlement(in entitlements: [String: Any]) -> Bool {
        return (entitlements[browserPublicKeyCredentialEntitlement] as? Bool) == true
    }

    private static let signedPasskeyEntitlementPresent: Bool = {
        guard let executableURL = Bundle.main.executableURL,
              let executableData = try? Data(contentsOf: executableURL),
              let entitlements = SignedEntitlementsReader.entitlements(inExecutableData: executableData) else {
            return false
        }

        return containsBrowserPublicKeyCredentialEntitlement(in: entitlements)
    }()
}

enum SignedEntitlementsReader {
    enum Endianness {
        case big
        case little
    }

    private static let fatMagic: UInt32 = 0xcafebabe
    private static let fatMagic64: UInt32 = 0xcafebabf
    private static let machOMagic32: UInt32 = 0xfeedface
    private static let machOMagic64: UInt32 = 0xfeedfacf
    private static let codeSignatureCommand: UInt32 = 0x1d
    private static let codeSignatureMagic: UInt32 = 0xfade0cc0
    private static let entitlementsMagic: UInt32 = 0xfade7171
    private static let entitlementsSlot: UInt32 = 5

    static func entitlements(inExecutableData data: Data) -> [String: Any]? {
        if let entitlements = entitlements(inMachOData: data, baseOffset: 0) {
            return entitlements
        }

        guard let magic = data.uint32(at: 0, endianness: .big),
              magic == fatMagic || magic == fatMagic64,
              let architectureCount = data.uint32(at: 4, endianness: .big) else {
            return nil
        }

        let isFat64 = magic == fatMagic64
        let architectureSize = isFat64 ? 32 : 20

        for index in 0..<Int(architectureCount) {
            let architectureOffset = 8 + index * architectureSize
            let sliceOffset: Int?

            if isFat64, let offset = data.uint64(at: architectureOffset + 8, endianness: .big) {
                sliceOffset = Int(offset)
            } else {
                sliceOffset = data.uint32(at: architectureOffset + 8, endianness: .big).map(Int.init)
            }

            guard let sliceOffset else { continue }

            if let entitlements = entitlements(inMachOData: data, baseOffset: sliceOffset) {
                return entitlements
            }
        }

        return nil
    }

    static func entitlements(inCodeSignature data: Data) -> [String: Any]? {
        return entitlements(inCodeSignatureData: data, range: 0..<data.count)
    }

    private static func entitlements(inMachOData data: Data, baseOffset: Int) -> [String: Any]? {
        let littleEndianMagic = data.uint32(at: baseOffset, endianness: .little)
        let bigEndianMagic = data.uint32(at: baseOffset, endianness: .big)
        let is64Bit: Bool
        let endianness: Endianness

        switch (littleEndianMagic, bigEndianMagic) {
        case (machOMagic64, _):
            is64Bit = true
            endianness = .little
        case (machOMagic32, _):
            is64Bit = false
            endianness = .little
        case (_, machOMagic64):
            is64Bit = true
            endianness = .big
        case (_, machOMagic32):
            is64Bit = false
            endianness = .big
        default:
            return nil
        }

        guard let loadCommandCount = data.uint32(at: baseOffset + 16, endianness: endianness) else {
            return nil
        }

        var loadCommandOffset = baseOffset + (is64Bit ? 32 : 28)

        for _ in 0..<Int(loadCommandCount) {
            guard let command = data.uint32(at: loadCommandOffset, endianness: endianness),
                  let commandSize = data.uint32(at: loadCommandOffset + 4, endianness: endianness),
                  commandSize >= 16 else {
                return nil
            }

            if command == codeSignatureCommand,
               let signatureOffset = data.uint32(at: loadCommandOffset + 8, endianness: endianness),
               let signatureSize = data.uint32(at: loadCommandOffset + 12, endianness: endianness) {
                let start = baseOffset + Int(signatureOffset)
                let end = start + Int(signatureSize)
                return entitlements(inCodeSignatureData: data, range: start..<end)
            }

            loadCommandOffset += Int(commandSize)
        }

        return nil
    }

    private static func entitlements(inCodeSignatureData data: Data, range: Range<Int>) -> [String: Any]? {
        guard data.indices.contains(range.lowerBound),
              range.upperBound <= data.count,
              data.uint32(at: range.lowerBound, endianness: .big) == codeSignatureMagic,
              let count = data.uint32(at: range.lowerBound + 8, endianness: .big) else {
            return nil
        }

        for index in 0..<Int(count) {
            let entryOffset = range.lowerBound + 12 + index * 8
            guard let slot = data.uint32(at: entryOffset, endianness: .big),
                  let blobOffset = data.uint32(at: entryOffset + 4, endianness: .big),
                  slot == entitlementsSlot else {
                continue
            }

            return entitlements(
                inBlobData: data,
                offset: range.lowerBound + Int(blobOffset),
                upperBound: range.upperBound
            )
        }

        return nil
    }

    private static func entitlements(inBlobData data: Data, offset: Int, upperBound: Int) -> [String: Any]? {
        guard data.uint32(at: offset, endianness: .big) == entitlementsMagic,
              let length = data.uint32(at: offset + 4, endianness: .big) else {
            return nil
        }

        let plistStart = offset + 8
        let plistEnd = offset + Int(length)

        guard plistStart <= plistEnd, plistEnd <= upperBound else {
            return nil
        }

        let plistData = data.subdata(in: plistStart..<plistEnd)
        return (try? PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        )) as? [String: Any]
    }
}

private extension Data {
    func uint32(at offset: Int, endianness: SignedEntitlementsReader.Endianness) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }

        let bytes = self[offset..<offset + 4]

        switch endianness {
        case .big:
            return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        case .little:
            return bytes.reversed().reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }
    }

    func uint64(at offset: Int, endianness: SignedEntitlementsReader.Endianness) -> UInt64? {
        guard offset >= 0, offset + 8 <= count else { return nil }

        let bytes = self[offset..<offset + 8]

        switch endianness {
        case .big:
            return bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        case .little:
            return bytes.reversed().reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }
    }
}
