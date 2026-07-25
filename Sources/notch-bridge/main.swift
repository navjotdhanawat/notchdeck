import Foundation
import ClaudeNotchCore

// notch-bridge <EventName> [subtype]  (monitoring mode: fire-and-forget)
// notch-bridge decide <EventName>     (decide mode: block on response, print body)
// Reads Claude Code hook JSON on stdin, adds env + matcher, POSTs to the running app.
// Monitoring mode: never blocks Claude Code, short timeout, always exits 0.
// Decide mode: blocks on response (long timeout), prints body on 200, passthrough on any failure.

func run() {
    var args = Array(CommandLine.arguments.dropFirst())   // drop program name
    guard !args.isEmpty else { exit(0) }

    // Optional leading "--agent <id>"; default "claude" for back-compat with old installs.
    var agentID = "claude"
    if args.first == "--agent", args.count >= 2 {
        agentID = args[1]
        args.removeFirst(2)
    }
    guard !args.isEmpty else { exit(0) }

    let isDecide = args[0] == "decide"
    let eventName = isDecide ? (args.count >= 2 ? args[1] : "") : args[0]
    let subtype: String? = isDecide ? nil : (args.count >= 2 ? args[1] : nil)
    guard !eventName.isEmpty else { exit(0) }

    // Read stdin (hook payload). Empty is acceptable.
    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
    var payload = (try? JSONSerialization.jsonObject(with: stdinData) as? [String: Any]) ?? [:]

    // Inject environment: forward only the curated allowlist the identifiers declare
    // (never the whole environment — env vars routinely hold secrets), plus our PID.
    let env = ProcessInfo.processInfo.environment
    var envOut: [String: Any] = [:]
    for key in TerminalIdentifierRegistry.default.allEnvKeys {
        if let value = env[key] { envOut[key] = value }
    }
    envOut["PID"] = String(ProcessInfo.processInfo.processIdentifier)
    payload["env"] = envOut
    if let subtype { payload["matcher"] = subtype }
    payload["hook_event_name"] = eventName
    payload["agent_id"] = agentID

    // Look up the running app's port + token. Absent => app not running => no-op.
    guard let cfg = try? BridgeConfigWriter.read(from: Paths.bridgeConfigURL) else { exit(0) }

    let encoded = eventName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventName
    let route = isDecide ? "decide" : "hook"
    guard let url = URL(string: "http://127.0.0.1:\(cfg.port)/\(route)/\(encoded)"),
          let body = try? JSONSerialization.data(withJSONObject: payload) else { exit(0) }

    // Fire-and-forget monitoring: short timeout, discard body. Decide: long timeout, print body.
    let reqTimeout: TimeInterval = isDecide ? 585 : 2.0
    let waitTimeout: DispatchTime = .now() + (isDecide ? 590 : 2.5)

    var req = URLRequest(url: url, timeoutInterval: reqTimeout)
    req.httpMethod = "POST"
    req.httpBody = body
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(cfg.token, forHTTPHeaderField: "X-ClaudeNotch-Token")

    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { data, resp, _ in
        if isDecide, let data, !data.isEmpty,
           (resp as? HTTPURLResponse)?.statusCode == 200 {
            FileHandle.standardOutput.write(data)   // non-empty JSON → the decision; empty → passthrough
        }
        sem.signal()
    }.resume()
    _ = sem.wait(timeout: waitTimeout)
    exit(0)   // any failure/timeout → nothing printed → passthrough
}

run()
