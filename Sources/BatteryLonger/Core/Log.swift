import Foundation
import os

enum Log {
    private static let logger = Logger(subsystem: "com.masterfabric.BatteryLonger", category: "app")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        FileHandle.standardError.write("[\(formatter.string(from: Date()))] \(message)\n".data(using: .utf8)!)
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        FileHandle.standardError.write("[\(formatter.string(from: Date()))] ERROR \(message)\n".data(using: .utf8)!)
    }
}
