import Foundation

struct HIDKeyMapping: Codable, Equatable {
    let HIDKeyboardModifierMappingSrc: UInt64
    let HIDKeyboardModifierMappingDst: UInt64
}

struct HIDUserKeyMappingPayload: Codable, Equatable {
    let UserKeyMapping: [HIDKeyMapping]
}

enum CapsLockRemapperError: LocalizedError {
    case hidutilUnavailable
    case readFailed(String)
    case writeFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .hidutilUnavailable:
            return "hidutil ist auf diesem Mac nicht verfugbar."
        case .readFailed(let details):
            return "Die aktuelle Caps-Lock-Belegung konnte nicht gelesen werden: \(details)"
        case .writeFailed(let details):
            return "Die Caps-Lock-Belegung konnte nicht gesetzt werden: \(details)"
        case .invalidResponse(let details):
            return "Die Antwort von hidutil konnte nicht verarbeitet werden: \(details)"
        }
    }
}

final class CapsLockRemapper {
    private let processRunner: ProcessRunning
    private var originalMappings: [HIDKeyMapping]?
    private var lockedMappingApplied = false

    init(processRunner: ProcessRunning = ProcessRunner()) {
        self.processRunner = processRunner
    }

    func applyLockedMapping() throws {
        guard !lockedMappingApplied else {
            return
        }

        let currentMappings = try fetchCurrentMappings()
        originalMappings = currentMappings

        var updatedMappings = currentMappings.filter {
            $0.HIDKeyboardModifierMappingSrc != Self.capsLockUsage
        }
        updatedMappings.append(
            HIDKeyMapping(
                HIDKeyboardModifierMappingSrc: Self.capsLockUsage,
                HIDKeyboardModifierMappingDst: Self.f18Usage
            )
        )

        try setMappings(updatedMappings)
        lockedMappingApplied = true
    }

    func restoreOriginalMapping() {
        guard lockedMappingApplied else {
            return
        }

        do {
            try setMappings(originalMappings ?? [])
        } catch {
        }

        originalMappings = nil
        lockedMappingApplied = false
    }

    static func mergedMappingsForLock(existingMappings: [HIDKeyMapping]) -> [HIDKeyMapping] {
        var updatedMappings = existingMappings.filter {
            $0.HIDKeyboardModifierMappingSrc != capsLockUsage
        }
        updatedMappings.append(
            HIDKeyMapping(
                HIDKeyboardModifierMappingSrc: capsLockUsage,
                HIDKeyboardModifierMappingDst: f18Usage
            )
        )
        return updatedMappings
    }

    static func parseMappings(from output: String) throws -> [HIDKeyMapping] {
        let trimmedOutput = normalizeHIDOutput(output)
        let compactOutput = trimmedOutput.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)

        if trimmedOutput.isEmpty || compactOutput == "(null)" || compactOutput == "()" {
            return []
        }

        if let data = trimmedOutput.data(using: .utf8),
           let jsonMappings = try? JSONDecoder().decode(HIDUserKeyMappingPayload.self, from: data).UserKeyMapping {
            return jsonMappings
        }

        if let plistMappings = parseLegacyHIDMappings(from: trimmedOutput) {
            return plistMappings
        }

        throw CapsLockRemapperError.invalidResponse(trimmedOutput)
    }

    static func payloadString(for mappings: [HIDKeyMapping]) throws -> String {
        let payload = HIDUserKeyMappingPayload(UserKeyMapping: mappings)
        let data = try JSONEncoder().encode(payload)

        guard let json = String(data: data, encoding: .utf8) else {
            throw CapsLockRemapperError.invalidResponse("Payload konnte nicht in UTF-8 gewandelt werden")
        }

        return json
    }

    private static func normalizeHIDOutput(_ output: String) -> String {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "UserKeyMapping:"

        if trimmedOutput.hasPrefix(prefix) {
            return String(trimmedOutput.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmedOutput
    }

    private static func parseLegacyHIDMappings(from output: String) -> [HIDKeyMapping]? {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let compactOutput = trimmedOutput.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)

        if compactOutput == "()" {
            return []
        }

        let objectPattern = #"\{[^\}]*\}"#
        guard let objectRegex = try? NSRegularExpression(pattern: objectPattern) else {
            return nil
        }

        let sourcePattern = #"HIDKeyboardModifierMappingSrc\s*=\s*(\d+)\s*;"#
        let destinationPattern = #"HIDKeyboardModifierMappingDst\s*=\s*(\d+)\s*;"#

        guard
            let sourceRegex = try? NSRegularExpression(pattern: sourcePattern),
            let destinationRegex = try? NSRegularExpression(pattern: destinationPattern)
        else {
            return nil
        }

        let fullRange = NSRange(trimmedOutput.startIndex..<trimmedOutput.endIndex, in: trimmedOutput)
        let matches = objectRegex.matches(in: trimmedOutput, options: [], range: fullRange)

        if matches.isEmpty {
            return nil
        }

        var mappings: [HIDKeyMapping] = []

        for match in matches {
            guard let objectRange = Range(match.range, in: trimmedOutput) else {
                continue
            }

            let objectString = String(trimmedOutput[objectRange])
            let objectNSRange = NSRange(objectString.startIndex..<objectString.endIndex, in: objectString)

            guard
                let sourceMatch = sourceRegex.firstMatch(in: objectString, options: [], range: objectNSRange),
                let destinationMatch = destinationRegex.firstMatch(in: objectString, options: [], range: objectNSRange),
                let sourceRange = Range(sourceMatch.range(at: 1), in: objectString),
                let destinationRange = Range(destinationMatch.range(at: 1), in: objectString),
                let sourceValue = UInt64(objectString[sourceRange]),
                let destinationValue = UInt64(objectString[destinationRange])
            else {
                return nil
            }

            mappings.append(
                HIDKeyMapping(
                    HIDKeyboardModifierMappingSrc: sourceValue,
                    HIDKeyboardModifierMappingDst: destinationValue
                )
            )
        }

        return mappings
    }

    private func fetchCurrentMappings() throws -> [HIDKeyMapping] {
        let result = try processRunner.run(
            executableURL: URL(fileURLWithPath: Self.hidutilPath),
            arguments: ["property", "--get", "UserKeyMapping"]
        )

        guard result.exitCode == 0 else {
            throw CapsLockRemapperError.readFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }

        return try Self.parseMappings(from: result.stdout)
    }

    private func setMappings(_ mappings: [HIDKeyMapping]) throws {
        let payload = try Self.payloadString(for: mappings)
        let result = try processRunner.run(
            executableURL: URL(fileURLWithPath: Self.hidutilPath),
            arguments: ["property", "--set", payload]
        )

        guard result.exitCode == 0 else {
            throw CapsLockRemapperError.writeFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    private static let hidutilPath = "/usr/bin/hidutil"
    static let capsLockUsage: UInt64 = 0x700000039
    static let f18Usage: UInt64 = 0x70000006D
}

protocol ProcessRunning {
    func run(executableURL: URL, arguments: [String]) throws -> ProcessResult
}

struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

struct ProcessRunner: ProcessRunning {
    func run(executableURL: URL, arguments: [String]) throws -> ProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw CapsLockRemapperError.hidutilUnavailable
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}