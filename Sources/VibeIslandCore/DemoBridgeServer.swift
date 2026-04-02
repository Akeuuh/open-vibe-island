import Dispatch
import Darwin
import Foundation

public final class DemoBridgeServer: @unchecked Sendable {
    private struct ClientConnection {
        let id: UUID
        let fileDescriptor: Int32
        let readSource: DispatchSourceRead
        var buffer = Data()
    }

    private let socketURL: URL
    private let queue = DispatchQueue(label: "app.vibeisland.bridge.server")
    private let queueKey = DispatchSpecificKey<Void>()

    private var listeningFileDescriptor: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var clients: [UUID: ClientConnection] = [:]
    private var scheduledItems: [DispatchWorkItem] = []
    private var state = SessionState()

    public init(socketURL: URL = BridgeSocketLocation.defaultURL) {
        self.socketURL = socketURL
        queue.setSpecific(key: queueKey, value: ())
    }

    deinit {
        stop()
    }

    public func start() throws {
        guard listeningFileDescriptor == -1 else {
            return
        }

        let parentURL = socketURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: socketURL)

        let listeningFileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listeningFileDescriptor != -1 else {
            throw BridgeTransportError.systemCallFailed("socket", errno)
        }

        do {
            var reuseAddress: Int32 = 1
            guard setsockopt(
                listeningFileDescriptor,
                SOL_SOCKET,
                SO_REUSEADDR,
                &reuseAddress,
                socklen_t(MemoryLayout<Int32>.size)
            ) != -1 else {
                throw BridgeTransportError.systemCallFailed("setsockopt", errno)
            }

            try withUnixSocketAddress(path: socketURL.path) { address, length in
                guard bind(listeningFileDescriptor, address, length) != -1 else {
                    throw BridgeTransportError.systemCallFailed("bind", errno)
                }
            }

            guard listen(listeningFileDescriptor, 16) != -1 else {
                throw BridgeTransportError.systemCallFailed("listen", errno)
            }

            try makeSocketNonBlocking(listeningFileDescriptor)
        } catch {
            close(listeningFileDescriptor)
            try? FileManager.default.removeItem(at: socketURL)
            throw error
        }

        self.listeningFileDescriptor = listeningFileDescriptor

        let acceptSource = DispatchSource.makeReadSource(fileDescriptor: listeningFileDescriptor, queue: queue)
        acceptSource.setEventHandler { [weak self] in
            self?.acceptPendingClients()
        }
        acceptSource.setCancelHandler { [weak self] in
            guard let self else {
                return
            }

            if self.listeningFileDescriptor != -1 {
                close(self.listeningFileDescriptor)
                self.listeningFileDescriptor = -1
            }
        }
        self.acceptSource = acceptSource
        acceptSource.resume()
    }

    public func stop() {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            stopLocked()
        } else {
            queue.sync {
                stopLocked()
            }
        }
    }

    private func stopLocked() {
        scheduledItems.forEach { $0.cancel() }
        scheduledItems.removeAll()

        let activeConnections = Array(clients.values)
        activeConnections.forEach { $0.readSource.cancel() }
        clients.removeAll()

        acceptSource?.cancel()
        acceptSource = nil

        if listeningFileDescriptor != -1 {
            close(listeningFileDescriptor)
            listeningFileDescriptor = -1
        }

        try? FileManager.default.removeItem(at: socketURL)
    }

    private func acceptPendingClients() {
        guard listeningFileDescriptor != -1 else {
            return
        }

        while true {
            let clientFileDescriptor = accept(listeningFileDescriptor, nil, nil)

            if clientFileDescriptor == -1 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    return
                }

                return
            }

            do {
                try makeSocketNonBlocking(clientFileDescriptor)
                configureClient(fileDescriptor: clientFileDescriptor)
            } catch {
                close(clientFileDescriptor)
            }
        }
    }

    private func configureClient(fileDescriptor: Int32) {
        let clientID = UUID()
        let readSource = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: queue)

        readSource.setEventHandler { [weak self] in
            self?.readAvailableData(from: clientID)
        }
        readSource.setCancelHandler { [weak self] in
            guard let self else {
                return
            }

            if let client = self.clients[clientID] {
                close(client.fileDescriptor)
            } else {
                close(fileDescriptor)
            }
        }

        clients[clientID] = ClientConnection(
            id: clientID,
            fileDescriptor: fileDescriptor,
            readSource: readSource
        )
        readSource.resume()

        send(.hello(BridgeHello()), to: clientID)
        resetDemo(broadcastToAllClients: true)
    }

    private func readAvailableData(from clientID: UUID) {
        guard var client = clients[clientID] else {
            return
        }

        var localBuffer = [UInt8](repeating: 0, count: 8_192)

        while true {
            let bytesRead = read(client.fileDescriptor, &localBuffer, localBuffer.count)

            if bytesRead > 0 {
                client.buffer.append(localBuffer, count: bytesRead)

                do {
                    let envelopes = try BridgeCodec.decodeLines(from: &client.buffer)
                    clients[clientID] = client

                    for envelope in envelopes {
                        if case let .command(command) = envelope {
                            handle(command)
                        }
                    }
                } catch {
                    removeClient(clientID)
                    return
                }

                continue
            }

            if bytesRead == 0 {
                removeClient(clientID)
                return
            }

            if errno == EAGAIN || errno == EWOULDBLOCK {
                clients[clientID] = client
                return
            }

            removeClient(clientID)
            return
        }
    }

    private func resetDemo(broadcastToAllClients: Bool) {
        scheduledItems.forEach { $0.cancel() }
        scheduledItems.removeAll()

        state = SessionState()
        let initialEvents = MockAgentScenario.initialEvents
        initialEvents.forEach { state.apply($0) }

        if broadcastToAllClients {
            broadcast(initialEvents.map(BridgeEnvelope.event))
        }

        for scheduled in MockAgentScenario.timeline(referenceDate: .now) {
            schedule(event: scheduled.event, after: scheduled.delay)
        }
    }

    private func handle(_ command: BridgeCommand) {
        switch command {
        case .resetDemo:
            resetDemo(broadcastToAllClients: true)

        case let .resolvePermission(sessionID, approved):
            let event: AgentEvent

            if approved {
                event = .activityUpdated(
                    SessionActivityUpdated(
                        sessionID: sessionID,
                        summary: "Permission approved. Agent resumed work.",
                        phase: .running,
                        timestamp: .now
                    )
                )
                schedule(
                    event: .sessionCompleted(
                        SessionCompleted(
                            sessionID: sessionID,
                            summary: "Auth middleware patch applied after approval.",
                            timestamp: .now.addingTimeInterval(4)
                        )
                    ),
                    after: 4
                )
            } else {
                event = .sessionCompleted(
                    SessionCompleted(
                        sessionID: sessionID,
                        summary: "Permission denied. Review the session in the terminal.",
                        timestamp: .now
                    )
                )
            }

            state.apply(event)
            broadcast([.event(event)])

        case let .answerQuestion(sessionID, answer):
            let resumeEvent = AgentEvent.activityUpdated(
                SessionActivityUpdated(
                    sessionID: sessionID,
                    summary: "Answered: \(answer)",
                    phase: .running,
                    timestamp: .now
                )
            )

            state.apply(resumeEvent)
            broadcast([.event(resumeEvent)])
            schedule(
                event: .sessionCompleted(
                    SessionCompleted(
                        sessionID: sessionID,
                        summary: "Slow query analysis finished after targeting \(answer.lowercased()).",
                        timestamp: .now.addingTimeInterval(4)
                    )
                ),
                after: 4
            )
        }
    }

    private func schedule(event: AgentEvent, after delay: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.state.apply(event)
            self.broadcast([.event(event)])
        }

        scheduledItems.append(item)
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func send(_ envelope: BridgeEnvelope, to clientID: UUID) {
        guard let client = clients[clientID] else {
            return
        }

        do {
            let data = try BridgeCodec.encodeLine(envelope)
            try writeAll(data, to: client.fileDescriptor)
        } catch {
            removeClient(clientID)
        }
    }

    private func broadcast(_ envelopes: [BridgeEnvelope]) {
        let clientIDs = Array(clients.keys)

        for clientID in clientIDs {
            for envelope in envelopes {
                send(envelope, to: clientID)
            }
        }
    }

    private func removeClient(_ clientID: UUID) {
        guard let client = clients.removeValue(forKey: clientID) else {
            return
        }

        client.readSource.cancel()
    }
}
