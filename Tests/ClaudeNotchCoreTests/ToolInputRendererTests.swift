import XCTest
@testable import ClaudeNotchCore

final class ToolInputRendererTests: XCTestCase {
    func testEditProducesDiff() {
        let p = ToolInputRenderer.render(tool: "Edit",
            input: ["file_path": "a.ts", "old_string": "let x = 1", "new_string": "let x = 2"])
        guard case let .diff(file, lines) = p else { return XCTFail("expected diff") }
        XCTAssertEqual(file, "a.ts")
        XCTAssertEqual(lines, [DiffLine(kind: .removed, text: "let x = 1"),
                               DiffLine(kind: .added, text: "let x = 2")])
    }

    func testWriteProducesAllAddedDiff() {
        let p = ToolInputRenderer.render(tool: "Write", input: ["file_path": "n.txt", "content": "a\nb"])
        guard case let .diff(file, lines) = p else { return XCTFail("expected diff") }
        XCTAssertEqual(file, "n.txt")
        XCTAssertEqual(lines, [DiffLine(kind: .added, text: "a"), DiffLine(kind: .added, text: "b")])
    }

    func testBashProducesCommand() {
        let p = ToolInputRenderer.render(tool: "Bash", input: ["command": "rm -rf build"])
        XCTAssertEqual(p, .command("rm -rf build"))
    }

    func testUnknownToolFallsBackToRaw() {
        let p = ToolInputRenderer.render(tool: "Grep", input: ["pattern": "foo"])
        guard case .raw = p else { return XCTFail("expected raw") }
    }

    func testClaudeToolRendererMatchesEnum() {
        let r = ClaudeToolRenderer()
        XCTAssertEqual(r.render(tool: "Bash", input: ["command": "ls"]), .command("ls"))
        XCTAssertEqual(r.actionLabel(toolName: "Read", input: ["file_path": "/a/b.swift"]), "Read b.swift")
        XCTAssertNil(r.actionLabel(toolName: nil, input: nil))
    }
}
