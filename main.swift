import CosmogAI
import Foundation

@main
struct CosmogAIRunner {
    static func main() throws {
        let store = try DriveStore()
        let arguments = Array(CommandLine.arguments.dropFirst())

        switch arguments.first {
        case "--read" where arguments.count == 2:
            let bytes = try store.readFromDrive(arguments[1])
            FileHandle.standardOutput.write(bytes)
        case "--write" where arguments.count >= 3:
            let text = arguments.dropFirst(2).joined(separator: " ")
            try store.writeToDrive(arguments[1], data: Data(text.utf8))
            print("Wrote \(text.utf8.count) bytes to \(arguments[1])")
        case "--cuda-transform" where arguments.count == 4 || arguments.count == 5:
            let pluginURL = try store.fileURL(for: arguments[1])
            let input = try store.readFromDrive(arguments[2])
            var capacity: Int?
            if arguments.count == 5 {
                guard let parsedCapacity = Int(arguments[4]) else {
                    throw RunnerError.invalidOutputCapacity(arguments[4])
                }
                capacity = parsedCapacity
            }
            let output = try CUDAPlugin(libraryAt: pluginURL).transform(input, outputCapacity: capacity)
            try store.writeToDrive(arguments[3], data: output)
            print("CUDA plugin wrote \(output.count) bytes to \(arguments[3])")
        default:
            print("CosmogAI runner ready. Drive root: \(store.rootURL.path)")
            print("Usage: cosmogai [--read path | --write path text... | --cuda-transform plugin input output [capacity]]")
            if let devices = ProcessInfo.processInfo.environment["CUDA_VISIBLE_DEVICES"] {
                print("CUDA_VISIBLE_DEVICES=\(devices)")
            }
        }
    }
}

private enum RunnerError: Error, LocalizedError {
    case invalidOutputCapacity(String)

    var errorDescription: String? {
        switch self {
        case .invalidOutputCapacity(let value):
            return "Output capacity must be an integer, got: \(value)"
        }
    }
}
