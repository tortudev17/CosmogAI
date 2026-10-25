import Foundation

public enum DriveStoreError: Error, LocalizedError {
    case missingDriveRoot
    case invalidRelativePath(String)

    public var errorDescription: String? {
        switch self {
        case .missingDriveRoot:
            return "Set COSMOGAI_DRIVE_ROOT to the mounted CosmogAI Drive folder."
        case .invalidRelativePath(let path):
            return "Drive paths must be relative and cannot contain empty, '.' or '..' components: \(path)"
        }
    }
}

/// Fast file access rooted at the mounted `MyDrive/CosmogAI` directory.
/// Reads use memory mapping when the platform supports it. Paths are always
/// relative to the configured root.
public struct DriveStore: Sendable {
    public static let rootEnvironmentKey = "COSMOGAI_DRIVE_ROOT"

    public let rootURL: URL

    /// Uses `COSMOGAI_DRIVE_ROOT` when `rootURL` is not provided.
    public init(rootURL: URL? = nil) throws {
        if let rootURL {
            self.rootURL = rootURL.standardizedFileURL
        } else if let configuredRoot = ProcessInfo.processInfo.environment[Self.rootEnvironmentKey],
                  !configuredRoot.isEmpty {
            self.rootURL = URL(fileURLWithPath: configuredRoot, isDirectory: true).standardizedFileURL
        } else {
            throw DriveStoreError.missingDriveRoot
        }
    }

    /// Reads a file without copying it into an intermediate Swift buffer where
    /// the operating system can memory-map it safely.
    public func readFromDrive(_ relativePath: String) throws -> Data {
        let fileURL = try fileURL(for: relativePath)
        return try Data(contentsOf: fileURL, options: [.mappedIfSafe])
    }

    /// Writes bytes beneath the Drive root. Set `atomically` to true when
    /// protecting against a partially written file matters more than write speed.
    public func writeToDrive(
        _ relativePath: String,
        data: Data,
        atomically: Bool = false
    ) throws {
        let fileURL = try fileURL(for: relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: atomically ? [.atomic] : [])
    }

    /// Resolves a safe relative path beneath the Drive root. This is useful for
    /// APIs, such as `CUDAPlugin`, that need a file URL rather than file bytes.
    public func fileURL(for relativePath: String) throws -> URL {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw DriveStoreError.invalidRelativePath(relativePath)
        }

        return components.reduce(rootURL) { current, component in
            current.appendingPathComponent(String(component), isDirectory: false)
        }
    }
}

/// Convenience API for code that wants to use the process-level Drive root.
public func readFromDrive(_ relativePath: String) throws -> Data {
    try DriveStore().readFromDrive(relativePath)
}

/// Convenience API for code that wants to use the process-level Drive root.
public func writeToDrive(
    _ relativePath: String,
    data: Data,
    atomically: Bool = false
) throws {
    try DriveStore().writeToDrive(relativePath, data: data, atomically: atomically)
}
