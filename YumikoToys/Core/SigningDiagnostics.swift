//
//  SigningDiagnostics.swift
//  YumikoToys
//
//  启动期签名状态诊断：
//  - 区分 ad-hoc 自签名 (codesign -s -)
//  - Developer ID / App Store / Apple Developer 签名
//  - 未签名
//
//  结果仅输出至日志，不影响主流程。
//

import Foundation

enum SigningDiagnostics {

    /// 签名类型（按 SecCodeCopySigningInformation 的 key 的语义推断）
    enum SignatureKind {
        case adHoc            // 自签名（证书 "-"）
        case appleDeveloper   // Apple Developer / Developer ID
        case appStore         // App Store 分发
        case notSigned        // 未签名
        case unknown(String)  // 其他，附带描述
    }

    /// 同步检测当前进程签名类型，输出到 LoggerService
    static func logCurrentSigningStatus() {
        DispatchQueue.global(qos: .background).async {
            let (kind, teamId, bundleId) = Self.inferCurrentStatus()
            let message =
                "[Signing] bundleId=\(bundleId ?? "n/a") " +
                "kind=\(String(describing: kind)) " +
                "teamId=\(teamId ?? "n/a")"
            LoggerService.shared.info(message)
        }
    }

    // MARK: - Core inspection

    private static func inferCurrentStatus() -> (kind: SignatureKind, teamId: String?, bundleId: String?) {
        guard let mainURL = Bundle.main.executableURL as CFURL? else {
            return (.unknown("Bundle.executableURL is nil"), nil, nil)
        }

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(mainURL, [], &staticCode)
        guard createStatus == errSecSuccess, let code = staticCode else {
            return (.notSigned, nil, Bundle.main.bundleIdentifier)
        }

        var infoRef: CFDictionary?
        // kSecCSDefaultFlags = 0
        let copyStatus = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: 0), &infoRef)
        guard copyStatus == errSecSuccess, let info = infoRef as? [CFString: Any] else {
            return (.notSigned, nil, Bundle.main.bundleIdentifier)
        }

        // 关键键（与 Security.SecCodeCopySigningInformation 对齐）
        let infoDict = info as [String: Any]
        let teamId = infoDict["teamid" as String] as? String
        let certs = infoDict["certificates" as String] as? [Any] ?? []
        let identifier = infoDict["identifier" as String] as? String
        let infoPlist = infoDict["info-plist" as String] as? [String: Any] ?? [:]
        let bundleId = (infoPlist[kCFBundleIdentifierKey as String] as? String) ?? Bundle.main.bundleIdentifier

        // 判断逻辑：
        // - 没有证书（certs 为空）→ adhoc / 未签名
        // - 存在 teamid（非空）且 certs 非空 → apple developer
        // - 否则分析证书主体（CN），查找 "Apple Distribution: / Developer ID Application:" / "3rd Party Mac Developer Application:"
        if certs.isEmpty {
            // 当用 codesign -s - 签名时，certificates 通常为空；identifier 为 bundleId
            return (identifier != nil ? .adHoc : .notSigned, nil, bundleId ?? identifier)
        }

        var foundKind: SignatureKind = .unknown("unable to inspect certificate CN")
        for raw in certs {
            if CFGetTypeID(raw as CFTypeRef) == SecCertificateGetTypeID() {
                let cert = raw as! SecCertificate
                if let subject = SecCertificateCopySubjectSummary(cert) as? String {
                    if subject.contains("Developer ID Application:")
                        || subject.contains("Developer ID Installer:") {
                        foundKind = .appleDeveloper
                        break
                    } else if subject.contains("Apple Distribution:")
                        || subject.contains("3rd Party Mac Developer Application:") {
                        // App Store / TestFlight 构建
                        foundKind = .appStore
                        break
                    } else if subject.contains("iPhone Developer:")
                        || subject.contains("Apple Development:") {
                        foundKind = .appleDeveloper
                        break
                    }
                }
            }
        }

        return (foundKind, teamId, bundleId)
    }
}

// MARK: - SignatureKind 描述

extension SigningDiagnostics.SignatureKind: CustomStringConvertible {
    var description: String {
        switch self {
        case .adHoc:
            return "adHoc(codesign --force --deep --sign -)"
        case .appleDeveloper:
            return "appleDeveloper"
        case .appStore:
            return "appStore"
        case .notSigned:
            return "notSigned"
        case .unknown(let detail):
            return "unknown(\(detail))"
        }
    }
}
