//
//  AppInfo.swift
//  DevSim
//

import Foundation

/// Name and version, whether running from the `.app` bundle or straight out of `.build`.
enum AppInfo {
    static let name = "DevSim"

    /// Kept in sync with `Scripts/build-app.sh`.
    static let fallbackVersion = "2.0.0"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? fallbackVersion
    }
}
