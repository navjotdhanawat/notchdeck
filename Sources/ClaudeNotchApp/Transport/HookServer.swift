import Foundation
import Network
import ClaudeNotchCore

public final class HookServer {
    private let token: String
    private let agents: AgentRegistry
    private let onEvent: (HookEvent) -> Void
    private let onDecision: ((HookEvent, @escaping (Decision) -> Void) -> Void)?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "claudenotch.hookserver")

    public init(token: String,
                agents: AgentRegistry = .default,
                onEvent: @escaping (HookEvent) -> Void,
                onDecision: ((HookEvent, @escaping (Decision) -> Void) -> Void)? = nil) {
        self.token = token
        self.agents = agents
        self.onEvent = onEvent
        self.onDecision = onDecision
    }

    public static func eventName(fromPath path: String) -> HookEventName? {
        // path like "/hook/Stop"
        guard let last = path.split(separator: "/").last else { return nil }
        return HookEventName(rawValue: String(last))
    }

    public func start() throws -> UInt16 {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback          // 127.0.0.1 only
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params)      // OS-assigned ephemeral port
        self.listener = listener

        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }

        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
            if case .failed = state { ready.signal() }
        }
        listener.start(queue: queue)
        _ = ready.wait(timeout: .now() + 3)
        guard let port = listener.port?.rawValue else {
            throw NSError(domain: "HookServer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "listener did not bind"])
        }
        return port
    }

    public func stop() { listener?.cancel(); listener = nil }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }

            if let (headers, body, complete) = Self.tryParse(buf) {
                if complete {
                    self.respond(conn, headers: headers, body: body)
                    return
                }
            }
            if error != nil || isComplete {
                conn.cancel(); return
            }
            self.receive(conn, buffer: buf)
        }
    }

    /// Returns (headerLines, body, isComplete) once full headers are present; isComplete true when
    /// the whole Content-Length body has arrived.
    private static func tryParse(_ buf: Data) -> (headers: [String], body: Data, isComplete: Bool)? {
        guard let sep = buf.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = buf.subdata(in: buf.startIndex..<sep.lowerBound)
        guard let headerStr = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerStr.components(separatedBy: "\r\n")
        let length = lines.first(where: { $0.lowercased().hasPrefix("content-length:") })
            .flatMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1)
                return parts.count > 1 ? Int(parts[1].trimmingCharacters(in: .whitespaces)) : nil
            } ?? 0
        let bodyStart = sep.upperBound
        let have = buf.distance(from: bodyStart, to: buf.endIndex)
        let body = buf.subdata(in: bodyStart..<buf.endIndex)
        return (lines, body, have >= length)
    }

    private func respond(_ conn: NWConnection, headers: [String], body: Data) {
        let requestLine = headers.first ?? ""
        let parts = requestLine.split(separator: " ")
        let path = parts.count >= 2 ? String(parts[1]) : ""
        let sentToken = headers.first(where: { $0.lowercased().hasPrefix("x-claudenotch-token:") })
            .map { line -> String in
                let parts = line.split(separator: ":", maxSplits: 1)
                return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            }

        guard sentToken == token else { return write(conn, status: "401 Unauthorized", body: Data()) }
        guard let name = Self.eventName(fromPath: path) else {
            return write(conn, status: "400 Bad Request", body: Data())
        }
        let provider = agents.provider(for: HookEvent.peekAgentID(body))
        guard let event = try? provider.eventMapper.decode(body, name: name, now: Date()) else {
            return write(conn, status: "400 Bad Request", body: Data())
        }

        if path.hasPrefix("/decide/"), let onDecision {
            // Hold the connection open until a decision resolves; then write the JSON body.
            onDecision(event) { [weak self] decision in
                let body: Data
                if case let .answer(answers) = decision {
                    body = provider.decisionEncoder.answerStdoutJSON(answers, originalToolInput: event.toolInput) ?? Data()
                } else {
                    body = provider.decisionEncoder.stdoutJSON(for: decision) ?? Data()   // passthrough → empty
                }
                self?.write(conn, status: "200 OK", body: body)
            }
        } else {
            onEvent(event)
            write(conn, status: "200 OK", body: Data())
        }
    }

    private func write(_ conn: NWConnection, status: String, body: Data) {
        var data = Data("HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        data.append(body)
        conn.send(content: data, completion: .contentProcessed { _ in conn.cancel() })
    }
}
