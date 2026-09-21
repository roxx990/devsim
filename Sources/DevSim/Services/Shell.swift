//
//  Shell.swift
//  DevSim
//

import Foundation

/// Minimal command runner, used for the handful of `simctl` calls.
nonisolated enum Shell {
    struct Result: Sendable {
        let status: Int32
        let output: String
        let errorOutput: String

        var succeeded: Bool { status == 0 }
    }

    static func run(_ launchPath: String, arguments: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return Result(status: -1, output: "", errorOutput: error.localizedDescription)
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Result(
            status: process.terminationStatus,
            output: String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
            errorOutput: String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
