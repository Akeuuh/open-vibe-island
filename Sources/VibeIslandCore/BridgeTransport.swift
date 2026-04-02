import Darwin
import Foundation

public enum BridgeSocketLocation {
    public static var defaultURL: URL {
        URL(fileURLWithPath: "/tmp/vibe-island-\(getuid()).sock")
    }

    public static func uniqueTestURL() -> URL {
        URL(fileURLWithPath: "/tmp/vibe-island-test-\(UUID().uuidString).sock")
    }
}

public enum BridgeTransportError: Error, LocalizedError {
    case alreadyConnected
    case notConnected
    case malformedEnvelope
    case listenerFailed(String)
    case socketPathTooLong
    case systemCallFailed(String, Int32)

    public var errorDescription: String? {
        switch self {
        case .alreadyConnected:
            "The bridge client is already connected."
        case .notConnected:
            "The bridge client is not connected."
        case .malformedEnvelope:
            "The bridge transport received malformed data."
        case let .listenerFailed(message):
            "The local bridge listener failed: \(message)"
        case .socketPathTooLong:
            "The Unix socket path is too long for `sockaddr_un`."
        case let .systemCallFailed(name, code):
            "\(name) failed with errno \(code)."
        }
    }
}

public struct BridgeHello: Equatable, Codable, Sendable {
    public var protocolVersion: Int
    public var serverLabel: String

    public init(protocolVersion: Int = 1, serverLabel: String = "demo-bridge") {
        self.protocolVersion = protocolVersion
        self.serverLabel = serverLabel
    }
}

public enum BridgeCommand: Equatable, Codable, Sendable {
    case resetDemo
    case resolvePermission(sessionID: String, approved: Bool)
    case answerQuestion(sessionID: String, answer: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case sessionID
        case approved
        case answer
    }

    private enum CommandType: String, Codable {
        case resetDemo
        case resolvePermission
        case answerQuestion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CommandType.self, forKey: .type)

        switch type {
        case .resetDemo:
            self = .resetDemo
        case .resolvePermission:
            self = .resolvePermission(
                sessionID: try container.decode(String.self, forKey: .sessionID),
                approved: try container.decode(Bool.self, forKey: .approved)
            )
        case .answerQuestion:
            self = .answerQuestion(
                sessionID: try container.decode(String.self, forKey: .sessionID),
                answer: try container.decode(String.self, forKey: .answer)
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .resetDemo:
            try container.encode(CommandType.resetDemo, forKey: .type)
        case let .resolvePermission(sessionID, approved):
            try container.encode(CommandType.resolvePermission, forKey: .type)
            try container.encode(sessionID, forKey: .sessionID)
            try container.encode(approved, forKey: .approved)
        case let .answerQuestion(sessionID, answer):
            try container.encode(CommandType.answerQuestion, forKey: .type)
            try container.encode(sessionID, forKey: .sessionID)
            try container.encode(answer, forKey: .answer)
        }
    }
}

public enum BridgeEnvelope: Equatable, Codable, Sendable {
    case hello(BridgeHello)
    case event(AgentEvent)
    case command(BridgeCommand)

    private enum CodingKeys: String, CodingKey {
        case type
        case hello
        case event
        case command
    }

    private enum EnvelopeType: String, Codable {
        case hello
        case event
        case command
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EnvelopeType.self, forKey: .type)

        switch type {
        case .hello:
            self = .hello(try container.decode(BridgeHello.self, forKey: .hello))
        case .event:
            self = .event(try container.decode(AgentEvent.self, forKey: .event))
        case .command:
            self = .command(try container.decode(BridgeCommand.self, forKey: .command))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .hello(payload):
            try container.encode(EnvelopeType.hello, forKey: .type)
            try container.encode(payload, forKey: .hello)
        case let .event(payload):
            try container.encode(EnvelopeType.event, forKey: .type)
            try container.encode(payload, forKey: .event)
        case let .command(payload):
            try container.encode(EnvelopeType.command, forKey: .type)
            try container.encode(payload, forKey: .command)
        }
    }
}

public enum BridgeCodec {
    private static let newline = UInt8(ascii: "\n")

    public static func encodeLine(_ envelope: BridgeEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        var data = try encoder.encode(envelope)
        data.append(newline)
        return data
    }

    public static func decodeLines(from buffer: inout Data) throws -> [BridgeEnvelope] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        var messages: [BridgeEnvelope] = []

        while let newlineIndex = buffer.firstIndex(of: newline) {
            let line = buffer.prefix(upTo: newlineIndex)
            buffer.removeSubrange(...newlineIndex)

            guard !line.isEmpty else {
                continue
            }

            do {
                let message = try decoder.decode(BridgeEnvelope.self, from: Data(line))
                messages.append(message)
            } catch {
                throw BridgeTransportError.malformedEnvelope
            }
        }

        return messages
    }
}

func withUnixSocketAddress<T>(
    path: String,
    _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T
) throws -> T {
    var address = sockaddr_un()
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    address.sun_family = sa_family_t(AF_UNIX)

    let pathBytes = Array(path.utf8)
    let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)

    guard pathBytes.count < maxPathLength else {
        throw BridgeTransportError.socketPathTooLong
    }

    withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
        rawBuffer.initializeMemory(as: UInt8.self, repeating: 0)

        for (index, byte) in pathBytes.enumerated() {
            rawBuffer[index] = byte
        }
    }

    let length = socklen_t(
        MemoryLayout.size(ofValue: address.sun_len) +
        MemoryLayout.size(ofValue: address.sun_family) +
        pathBytes.count + 1
    )

    return try withUnsafePointer(to: &address) { pointer in
        try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            try body(sockaddrPointer, length)
        }
    }
}

func makeSocketNonBlocking(_ fileDescriptor: Int32) throws {
    let currentFlags = fcntl(fileDescriptor, F_GETFL)
    guard currentFlags != -1 else {
        throw BridgeTransportError.systemCallFailed("fcntl(F_GETFL)", errno)
    }

    guard fcntl(fileDescriptor, F_SETFL, currentFlags | O_NONBLOCK) != -1 else {
        throw BridgeTransportError.systemCallFailed("fcntl(F_SETFL)", errno)
    }
}

func writeAll(_ data: Data, to fileDescriptor: Int32) throws {
    var remaining = data[...]

    while !remaining.isEmpty {
        let bytesWritten = remaining.withUnsafeBytes { rawBuffer -> Int in
            let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
            return write(fileDescriptor, baseAddress, rawBuffer.count)
        }

        if bytesWritten > 0 {
            remaining.removeFirst(bytesWritten)
            continue
        }

        if bytesWritten == -1 && (errno == EAGAIN || errno == EWOULDBLOCK) {
            usleep(1_000)
            continue
        }

        throw BridgeTransportError.systemCallFailed("write", errno)
    }
}
