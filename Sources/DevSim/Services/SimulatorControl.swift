//
//  SimulatorControl.swift
//  DevSim
//

import Foundation

/// Device operations that go through `simctl`.
///
/// `simctl` is picky about device state: `uninstall` only works on a booted device and
/// `erase` only on a shut down one. Each operation here puts the device into the state it
/// needs, does the work, and puts it back the way it found it.
nonisolated enum SimulatorControl {
    private static let xcrun = "/usr/bin/xcrun"

    struct Outcome: Sendable {
        let succeeded: Bool
        /// Empty when everything worked.
        let message: String
    }

    // MARK: - Applications

    /// Removes an app and its containers from a device.
    static func uninstall(bundleIdentifier: String, from device: Simulator.Reference) -> Outcome {
        let wasBooted = device.isBooted

        if !wasBooted {
            let boot = simctl(["bootstatus", device.udid, "-b"])
            guard boot.succeeded else { return failure("Could not boot \(device.name).", boot) }
        }

        let uninstall = simctl(["uninstall", device.udid, bundleIdentifier])

        // Leave the device as we found it, whether or not the uninstall worked.
        if !wasBooted {
            _ = simctl(["shutdown", device.udid])
        }

        guard uninstall.succeeded else {
            return failure("Could not uninstall \(bundleIdentifier).", uninstall)
        }
        return Outcome(succeeded: true, message: "")
    }

    // MARK: - Devices

    /// Erases all content and settings, the equivalent of Simulator's own Erase command.
    static func erase(_ device: Simulator.Reference) -> Outcome {
        let wasBooted = device.isBooted

        if wasBooted {
            let shutdown = simctl(["shutdown", device.udid])
            guard shutdown.succeeded else {
                return failure("Could not shut down \(device.name).", shutdown)
            }
        }

        let erase = simctl(["erase", device.udid])
        guard erase.succeeded else { return failure("Could not erase \(device.name).", erase) }

        // Bring it back up so the device is usable again straight away.
        if wasBooted {
            let boot = simctl(["bootstatus", device.udid, "-b"])
            guard boot.succeeded else {
                return failure("\(device.name) was erased but could not be booted again.", boot)
            }
        }
        return Outcome(succeeded: true, message: "")
    }

    static func boot(_ device: Simulator.Reference) -> Outcome {
        let result = simctl(["bootstatus", device.udid, "-b"])
        return result.succeeded
            ? Outcome(succeeded: true, message: "")
            : failure("Could not boot \(device.name).", result)
    }

    static func shutDown(_ device: Simulator.Reference) -> Outcome {
        let result = simctl(["shutdown", device.udid])
        return result.succeeded
            ? Outcome(succeeded: true, message: "")
            : failure("Could not shut down \(device.name).", result)
    }

    static func screenshot(_ device: Simulator.Reference, to destination: URL) -> Outcome {
        let result = simctl(["io", device.udid, "screenshot", destination.path])
        return result.succeeded
            ? Outcome(succeeded: true, message: "")
            : failure("Could not capture a screenshot of \(device.name).", result)
    }

    // MARK: - Private

    private static func simctl(_ arguments: [String]) -> Shell.Result {
        Shell.run(xcrun, arguments: ["simctl"] + arguments)
    }

    private static func failure(_ summary: String, _ result: Shell.Result) -> Outcome {
        // simctl puts both its progress chatter and its errors on stderr.
        let detail = result.errorOutput.isEmpty
            ? "simctl exited with code \(result.status)."
            : result.errorOutput
        return Outcome(succeeded: false, message: "\(summary)\n\n\(detail)")
    }
}
