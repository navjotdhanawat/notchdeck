#!/usr/bin/env swift

import Foundation

// Find the compiled notch-bridge binary
let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath

let debugPath = "\(currentDir)/.build/arm64-apple-macosx/debug/notch-bridge"
let releasePath = "\(currentDir)/.build/arm64-apple-macosx/release/notch-bridge"

let bridgePath: String
if fileManager.fileExists(atPath: debugPath) {
    bridgePath = debugPath
} else if fileManager.fileExists(atPath: releasePath) {
    bridgePath = releasePath
} else {
    print("Error: Could not find compiled notch-bridge. Please run 'swift build' first.")
    exit(1)
}

func sendEvent(_ name: String, json: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: bridgePath)
    process.arguments = [name]

    let inputPipe = Pipe()
    process.standardInput = inputPipe

    // Silence output to stdout/stderr
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
        try process.run()
        try inputPipe.fileHandleForWriting.write(contentsOf: Data(json.utf8))
        try inputPipe.fileHandleForWriting.close()
        process.waitUntilExit()
    } catch {
        print("Failed to send event \(name): \(error)")
    }
}

// Arguments check
let args = CommandLine.arguments
let action = args.count > 1 ? args[1] : "demo"

let sessionID = "test-session-\(Int.random(in: 1000...9999))"
let cwd = currentDir

print("Starting simulation for action: \(action) with sessionID: \(sessionID)")

if action == "success" {
    // 1. Start Session
    print("Sending SessionStart...")
    sendEvent("SessionStart", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)"}"#)
    Thread.sleep(forTimeInterval: 1.0)

    // 2. PreToolUse
    print("Sending PreToolUse (working)...")
    sendEvent("PreToolUse", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)","tool_name":"Edit"}"#)
    Thread.sleep(forTimeInterval: 1.5)

    // 3. Stop (success chime)
    print("Sending Stop (playing success arpeggio)...")
    sendEvent("Stop", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)"}"#)

} else if action == "failure" {
    // 1. Start Session
    print("Sending SessionStart...")
    sendEvent("SessionStart", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)"}"#)
    Thread.sleep(forTimeInterval: 1.0)

    // 2. PreToolUse
    print("Sending PreToolUse (working)...")
    sendEvent("PreToolUse", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)","tool_name":"Bash"}"#)
    Thread.sleep(forTimeInterval: 1.5)

    // 3. StopFailure (failure chime)
    print("Sending StopFailure (playing failure audio)...")
    sendEvent("StopFailure", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)"}"#)

} else if action == "permission" {
    // Starts session and sends permission request card
    print("Sending SessionStart...")
    sendEvent("SessionStart", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)"}"#)
    Thread.sleep(forTimeInterval: 0.8)

    print("Sending PermissionRequest (pop-up card)...")
    sendEvent("PermissionRequest", json: #"""
    {"session_id":"\#(sessionID)","cwd":"\#(cwd)","tool_name":"Bash",
     "tool_input":{"command":"make clean && make build"}}
    """#)

} else {
    // Standard Demo arpeggios play
    print("Sending SessionStart...")
    sendEvent("SessionStart", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)"}"#)
    Thread.sleep(forTimeInterval: 0.5)

    print("Sending PreToolUse (working)...")
    sendEvent("PreToolUse", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)","tool_name":"LSP"}"#)
    Thread.sleep(forTimeInterval: 1.2)

    print("Sending Stop (Success audio)...")
    sendEvent("Stop", json: #"{"session_id":"\#(sessionID)","cwd":"\#(cwd)"}"#)
}

print("Simulation finished.")
