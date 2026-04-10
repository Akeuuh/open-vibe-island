import Foundation

public enum GeminiHookInstallationStatus: Equatable, Sendable {
    case notInstalled
    case installed(hookCommand: String)
    case geminiNotFound
}

public final class GeminiHookInstallationManager: @unchecked Sendable {
    private let geminiDirectory: URL

    public init(
        geminiDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini", isDirectory: true)
    ) {
        self.geminiDirectory = geminiDirectory
    }

    private var settingsURL: URL {
        geminiDirectory.appendingPathComponent("settings.json")
    }

    public func status(hooksBinaryURL: URL? = nil) throws -> GeminiHookInstallationStatus {
        guard FileManager.default.fileExists(atPath: geminiDirectory.path) else {
            return .geminiNotFound
        }
        guard let data = try? Data(contentsOf: settingsURL) else {
            return .notInstalled
        }
        guard let binaryURL = hooksBinaryURL else {
            return .notInstalled
        }
        let hookCommand = GeminiHookInstaller.hookCommand(for: binaryURL.path)
        guard let mutation = try? GeminiHookInstaller.uninstallSettingsJSON(
            existingData: data,
            hookCommand: hookCommand
        ) else {
            return .notInstalled
        }
        return mutation.managedHooksPresent
            ? .installed(hookCommand: hookCommand)
            : .notInstalled
    }

    @discardableResult
    public func install(hooksBinaryURL: URL) throws -> GeminiHookInstallationStatus {
        try FileManager.default.createDirectory(at: geminiDirectory, withIntermediateDirectories: true)
        let existingData = try? Data(contentsOf: settingsURL)
        let hookCommand = GeminiHookInstaller.hookCommand(for: hooksBinaryURL.path)
        let mutation = try GeminiHookInstaller.installSettingsJSON(
            existingData: existingData,
            hookCommand: hookCommand
        )
        if let contents = mutation.contents {
            try contents.write(to: settingsURL, options: .atomic)
        }
        return .installed(hookCommand: hookCommand)
    }

    @discardableResult
    public func uninstall(hooksBinaryURL: URL) throws -> GeminiHookInstallationStatus {
        let existingData = try? Data(contentsOf: settingsURL)
        let hookCommand = GeminiHookInstaller.hookCommand(for: hooksBinaryURL.path)
        let mutation = try GeminiHookInstaller.uninstallSettingsJSON(
            existingData: existingData,
            hookCommand: hookCommand
        )
        if let contents = mutation.contents {
            try contents.write(to: settingsURL, options: .atomic)
        }
        return .notInstalled
    }
}
