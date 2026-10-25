import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#else
#error("CosmogAI CUDA plugins require a platform with dlopen support.")
#endif

public enum CUDAPluginError: Error, LocalizedError {
    case loadFailed(String)
    case missingEntryPoint(String)
    case executionFailed(Int32)
    case invalidOutputSize(UInt64, UInt64)
    case invalidOutputCapacity(Int)

    public var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Could not load the CUDA plugin: \(message)"
        case .missingEntryPoint(let message):
            return "Could not find cosmogai_cuda_transform in the CUDA plugin: \(message)"
        case .executionFailed(let status):
            return "CUDA plugin returned status \(status)."
        case .invalidOutputSize(let actual, let capacity):
            return "CUDA plugin returned \(actual) bytes, beyond its \(capacity)-byte output buffer."
        case .invalidOutputCapacity(let capacity):
            return "CUDA output capacity cannot be negative: \(capacity)."
        }
    }
}

/// Loads an optional C ABI plugin at runtime, so CPU-only builds do not link
/// against CUDA. The plugin may use CUDA and must export
/// `cosmogai_cuda_transform` with the ABI documented in README.md.
public final class CUDAPlugin {
    private typealias TransformFunction = @convention(c) (
        UnsafePointer<UInt8>?, UInt64,
        UnsafeMutablePointer<UInt8>?, UInt64,
        UnsafeMutablePointer<UInt64>?
    ) -> Int32

    private let handle: UnsafeMutableRawPointer
    private let transformFunction: TransformFunction

    public init(libraryAt url: URL) throws {
        guard let loadedHandle = dlopen(url.path, RTLD_NOW | RTLD_LOCAL) else {
            throw CUDAPluginError.loadFailed(Self.dynamicLoaderMessage())
        }
        guard let symbol = dlsym(loadedHandle, "cosmogai_cuda_transform") else {
            let message = Self.dynamicLoaderMessage()
            dlclose(loadedHandle)
            throw CUDAPluginError.missingEntryPoint(message)
        }

        self.handle = loadedHandle
        self.transformFunction = unsafeBitCast(symbol, to: TransformFunction.self)
    }

    deinit {
        dlclose(handle)
    }

    /// Runs a transform. By default, output capacity equals the input length;
    /// provide a larger capacity for operations that expand their output.
    public func transform(_ input: Data, outputCapacity: Int? = nil) throws -> Data {
        let requestedCapacity = outputCapacity ?? input.count
        guard requestedCapacity >= 0 else {
            throw CUDAPluginError.invalidOutputCapacity(requestedCapacity)
        }

        var output = Data(count: requestedCapacity)
        var outputSize: UInt64 = 0
        let capacity = UInt64(output.count)

        let status = input.withUnsafeBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                transformFunction(
                    inputBytes.bindMemory(to: UInt8.self).baseAddress,
                    UInt64(input.count),
                    outputBytes.bindMemory(to: UInt8.self).baseAddress,
                    capacity,
                    &outputSize
                )
            }
        }

        guard status == 0 else {
            throw CUDAPluginError.executionFailed(status)
        }
        guard outputSize <= capacity else {
            throw CUDAPluginError.invalidOutputSize(outputSize, capacity)
        }
        output.count = Int(outputSize)
        return output
    }

    private static func dynamicLoaderMessage() -> String {
        guard let message = dlerror() else { return "unknown dynamic loader error" }
        return String(cString: message)
    }
}
