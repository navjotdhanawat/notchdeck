# ClaudeNotch Interaction Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the notch usable for parallel sessions — reliable terminal jump, hover-to-reveal session detail, and answer-in-place for AskUserQuestion.

**Architecture:** Three connected workstreams built C → A → B. **C** wires the existing AppleScript terminal jumper into the decision path and hardens it. **A** bridges DynamicNotchKit's `isHovering` into `NotchController`'s presentation pump so hover reveals the existing rich rows. **B** adds a synchronous PreToolUse hook for `AskUserQuestion`, a new `DecisionKind.question` + `Decision.answer`, and an event-aware encoder that returns `permissionDecision:"allow"` + `updatedInput.answers` — verified to answer the question without the terminal menu.

**Tech Stack:** Swift 5.9 / SwiftPM, macOS AppKit + SwiftUI, DynamicNotchKit, Combine, Network (loopback hook server), AppleScript (iTerm2), Claude Code hooks.

## Global Constraints

- **Decisions require Claude Code ≥ 2.1.200** — gated by `AppCoordinator.detectDecisionsSupported()` (`ClaudeVersion.meetsMinimum(out, (2, 1, 200))`). All B-workstream hooks install only when `decisionsEnabled`.
- **Verified answer-in-place contract (do not change the shape):** a synchronous `PreToolUse` hook matched to `AskUserQuestion` returns `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{…original tool_input…,"answers":{"<question text>":"<chosen label>"}}}}`. Single-select answer value is a **string**.
- **AskUserQuestion `tool_input` shape:** `{"questions":[{"question":String,"header":String,"options":[{"label":String,"description":String}],"multiSelect":Bool}]}`.
- **No new tests** (per repo owner's standing instruction): verify with `swift build` + `swift test` (existing suite) + manual e2e. Update existing tests only where a contract they cover changes. Do NOT add new test files, classes, functions, or cases.
- **Commits:** Conventional Commits, **no JIRA prefix** (this repo is local-only; matches existing history like `fix: …`). End every commit message with a trailing blank line then `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Branch first:** we are on `main`. Before Task C1, create and switch to `feat/claudenotch-interaction-fixes`.

---

## Setup

- [ ] **Step 1: Create the feature branch**

Run:
```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git checkout -b feat/claudenotch-interaction-fixes
```
Expected: `Switched to a new branch 'feat/claudenotch-interaction-fixes'`

- [ ] **Step 2: Baseline build + test**

Run:
```bash
swift build && swift test 2>&1 | tail -20
```
Expected: build succeeds; existing tests pass. (If anything fails now, stop and report — do not start on a red baseline.)

---

## Workstream C — Reliable terminal jump

### Task C1: Session lookup by key

**Files:**
- Modify: `Sources/ClaudeNotchCore/Domain/SessionStore.swift`

**Interfaces:**
- Produces: `SessionStore.session(forKey key: String) -> Session?`

- [ ] **Step 1: Add the lookup method**

In `SessionStore` (after `updateUsage`, before `purge`), add:
```swift
/// Look up a session by its derived key — used to jump to the terminal from a decision request.
public func session(forKey key: String) -> Session? {
    sessions[key]
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds successfully.

- [ ] **Step 3: Run existing tests**

Run: `swift test 2>&1 | tail -20`
Expected: existing tests pass (SessionStoreTests unaffected).

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/SessionStore.swift
git commit
```
Message subject: `feat: add SessionStore.session(forKey:) lookup`

---

### Task C2: Wire the terminal jump into the decision "Answer in terminal" action

**Files:**
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift` (NotchViewModel, DecisionCardView, NotchExpandedView)
- Modify: `Sources/ClaudeNotchApp/UI/NotchController.swift`
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift`

**Interfaces:**
- Consumes: `SessionStore.session(forKey:)` (C1), existing `TerminalJumperRegistry`, `DecisionBroker.resolve(id:_:)`.
- Produces: `NotchController.onAnswerInTerminal: ((DecisionRequest) -> Void)?`; `NotchViewModel.onAnswerInTerminal`.

- [ ] **Step 1: Add `onAnswerInTerminal` to the view model**

In `NotchViews.swift`, in `NotchViewModel`, after `var onDecide: ...` add:
```swift
    var onAnswerInTerminal: ((DecisionRequest) -> Void)?
```

- [ ] **Step 2: Give `DecisionCardView` the terminal-jump closure and use it**

In `NotchViews.swift`, `DecisionCardView`: add a stored property after `var onDecide: ...`:
```swift
    var onAnswerInTerminal: ((DecisionRequest) -> Void)?
```
Then change the bottom button from:
```swift
                Button("Answer in terminal") { onDecide?(request, .passthrough) }.font(.caption)
```
to:
```swift
                Button("Answer in terminal") { onAnswerInTerminal?(request) }.font(.caption)
```

- [ ] **Step 3: Pass the closure through `NotchExpandedView`**

In `NotchViews.swift`, `NotchExpandedView`, change the card construction from:
```swift
                DecisionCardView(request: req, remaining: vm.pendingDecisions.count - 1, onDecide: vm.onDecide)
```
to:
```swift
                DecisionCardView(request: req, remaining: vm.pendingDecisions.count - 1,
                                 onDecide: vm.onDecide, onAnswerInTerminal: vm.onAnswerInTerminal)
```

- [ ] **Step 4: Expose it on `NotchController`**

In `NotchController.swift`, after the `onDecide` property, add:
```swift
    public var onAnswerInTerminal: ((DecisionRequest) -> Void)? {
        didSet { vm.onAnswerInTerminal = onAnswerInTerminal }
    }
```

- [ ] **Step 5: Wire it in `AppCoordinator` (jump + passthrough)**

In `AppCoordinator.applicationDidFinishLaunching`, immediately after the `notch.onDecide = { … }` block (step 5 area), add:
```swift
        // "Answer in terminal": focus the session's terminal, then let Claude show its own prompt.
        notch.onAnswerInTerminal = { [weak self] req in
            Task { @MainActor in
                guard let self else { return }
                if let session = self.store.session(forKey: req.sessionKey) {
                    let result = await self.registry.jumper(for: session).jump(to: session)
                    if case .failed = result {
                        self.sound.playError()
                        self.notch.showNotice("Couldn't focus that terminal — check Automation permission")
                    }
                }
                await self.broker.resolve(id: req.id, .passthrough)
            }
        }
```

- [ ] **Step 6: Build**

Run: `swift build`
Expected: builds successfully.

- [ ] **Step 7: Run existing tests**

Run: `swift test 2>&1 | tail -20`
Expected: existing tests pass.

- [ ] **Step 8: Manual e2e**

Run the app (`swift run ClaudeNotchApp` or the built binary), trigger any tool-permission decision in a Claude session, click **Answer in terminal** in the notch. Expected: the correct terminal window/tab comes to the front, then Claude's own prompt appears. If it fails, the notch shows the Automation-permission notice + error sound (that path is verified in C3).

- [ ] **Step 9: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchViews.swift Sources/ClaudeNotchApp/UI/NotchController.swift Sources/ClaudeNotchApp/AppCoordinator.swift
git commit
```
Message subject: `fix: focus the terminal when answering a decision in the terminal`

---

### Task C3: Automation (TCC) + tmux jump investigation

**Files:**
- Modify (only if a quick win falls out): `Sources/ClaudeNotchApp/Terminal/ITerm2Jumper.swift`
- Modify: `docs/superpowers/specs/2026-07-23-claudenotch-interaction-fixes-design.md` (record the C2 outcome)

**Interfaces:** none new.

- [ ] **Step 1: Confirm the Automation permission path**

With the app running, trigger a jump (click a session row). The first time, macOS should prompt *"ClaudeNotchApp wants to control iTerm2."* Grant it. Verify under **System Settings → Privacy & Security → Automation → ClaudeNotchApp → iTerm** the toggle is on. If the prompt never appears and the jump fails, check whether the app is sandboxed / has an `NSAppleEventsUsageDescription`; document the finding.

- [ ] **Step 2: Confirm the failure notice**

Temporarily deny Automation (toggle off), click a session row. Expected: error sound + notice *"Couldn't focus that terminal — check Automation permission"*. Re-enable Automation afterward.

- [ ] **Step 3: Investigate tmux precision**

The owner runs Claude inside tmux. Inspect what terminal identity the bridge actually captured for a live session: add a one-off `NSLog` of `session.terminal` in `AppCoordinator.onJump` (or read it in the debugger), run a session inside tmux, and record whether it is `.iterm(uuid:)` (and whether that UUID resolves) or `.other(...)`. Decide the stance:
  - If window/tab focus lands reliably (even if not the exact pane): accept as-is; document "per-pane precision is a known limitation."
  - If it lands on the wrong iTerm window entirely: note a follow-up to add tmux-aware selection (`tmux select-window`/`select-pane`) — **do not implement here** unless it is a one-liner.
Remove the temporary `NSLog` before committing.

- [ ] **Step 4: Record the outcome**

Update the **Workstream C → C2** section of the design spec with: Automation-permission behavior, the tmux terminal identity observed, and the chosen precision stance.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-07-23-claudenotch-interaction-fixes-design.md
git commit
```
Message subject: `docs: record terminal-jump Automation/tmux investigation outcome`

---

## Workstream A — Hover-to-expand session detail

### Task A1: Bridge `isHovering` into the presentation pump

**Files:**
- Modify: `Sources/ClaudeNotchApp/UI/NotchController.swift`

**Interfaces:**
- Consumes: `DynamicNotch.isHovering` (`@Published public private(set)`), existing `pump()` / `presentation(pending:sessions:)`.
- Produces: no external interface; internal hover state drives `.expanded`.

- [ ] **Step 1: Import Combine and add hover state**

At the top of `NotchController.swift`, add `import Combine` under the existing imports.
In `NotchController`, add these stored properties near `clock`/`noticeTimer`:
```swift
    private var isHovering = false
    private var hoverEnterTimer: Timer?
    private var hoverExitTimer: Timer?
    private var hoverCancellable: AnyCancellable?
    private let hoverEnterDelay: TimeInterval = 0.30
    private let hoverExitGrace: TimeInterval = 0.25
```

- [ ] **Step 2: Subscribe to hover in `init`**

At the end of `init()` (after the `notch = DynamicNotch(...)` assignment), add:
```swift
        // DynamicNotchKit's hover only enlarges the compact content — it does NOT reveal the
        // expanded view. Bridge its isHovering into our pump so hover flips us to .expanded.
        hoverCancellable = notch?.$isHovering
            .removeDuplicates()
            .sink { [weak self] hovering in
                Task { @MainActor in self?.hoverChanged(hovering) }
            }
```
> Fallback if `$isHovering` is not accessible from outside the module: replace the subscription with
> `hoverCancellable = notch?.objectWillChange.receive(on: RunLoop.main).sink { [weak self] in Task { @MainActor in self?.hoverChanged(self?.notch?.isHovering ?? false) } }`
> (`isHovering`'s getter is public; only its setter is private.)

- [ ] **Step 3: Add the debounce handlers**

Add these methods to `NotchController`:
```swift
    /// Debounce raw hover: enter after a short delay (avoid accidental menu-bar triggers),
    /// leave after a grace (absorb the blip when the panel grows under the cursor).
    private func hoverChanged(_ hovering: Bool) {
        if hovering {
            hoverExitTimer?.invalidate(); hoverExitTimer = nil
            guard hoverEnterTimer == nil, !isHovering else { return }
            hoverEnterTimer = Timer.scheduledTimer(withTimeInterval: hoverEnterDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.applyHover(true) }
            }
        } else {
            hoverEnterTimer?.invalidate(); hoverEnterTimer = nil
            guard hoverExitTimer == nil, isHovering else { return }
            hoverExitTimer = Timer.scheduledTimer(withTimeInterval: hoverExitGrace, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.applyHover(false) }
            }
        }
    }

    private func applyHover(_ value: Bool) {
        hoverEnterTimer = nil; hoverExitTimer = nil
        guard isHovering != value else { return }
        isHovering = value
        desiredPresentation = presentation(pending: vm.pendingDecisions, sessions: vm.sessions)
        pump()
    }
```

- [ ] **Step 4: Fold hover into `presentation(...)` and fix the stale comment**

Replace the body of `presentation(pending:sessions:)` with:
```swift
    private func presentation(pending: [DecisionRequest], sessions: [Session]) -> Presentation {
        if !pending.isEmpty { return .expanded }
        if !sessions.isEmpty { return isHovering ? .expanded : .compact }
        return .hidden
    }
```
Then replace the incorrect comment above `startClock()` (currently: *"DynamicNotchKit reveals the expanded view on hover even in the compact state…"*) with:
```swift
    // Session rows show live durations; the clock runs whenever the notch is visible so the times
    // tick in both compact and (hover-)expanded states.
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: builds successfully. (If it fails on `$isHovering` accessibility, apply the Step 2 fallback and rebuild.)

- [ ] **Step 6: Run existing tests**

Run: `swift test 2>&1 | tail -20`
Expected: existing tests pass.

- [ ] **Step 7: Manual e2e**

Run the app with ≥1 active Claude session (notch shows compact glyphs). Hover the notch: after ~0.3s it expands to the rich rows; move away: after ~0.25s it collapses. Trigger a pending decision: it still force-expands immediately regardless of hover. Rows are click-to-jump (via C).

- [ ] **Step 8: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchController.swift
git commit
```
Message subject: `feat: reveal session detail on hover (debounced expand)`

---

## Workstream B — AskUserQuestion answer-in-place

### Task B1: `Decision.answer` + answer encoder

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/Decision.swift`
- Modify: `Sources/ClaudeNotchCore/Domain/DecisionEncoder.swift`

**Interfaces:**
- Produces: `Decision.answer(answers: [String: String])`; `DecisionEncoder.answerStdoutJSON(_ answers: [String: String], originalToolInput: Data?) -> Data?`.

- [ ] **Step 1: Add the `.answer` case**

In `Decision.swift`, extend the `Decision` enum:
```swift
public enum Decision: Sendable, Equatable {
    case allow(scope: AllowScope)
    case deny(reason: String?)
    case passthrough
    /// AskUserQuestion answer: question text → chosen option label (single-select).
    case answer(answers: [String: String])
}
```

- [ ] **Step 2: Keep the PermissionRequest encoder exhaustive**

In `DecisionEncoder.stdoutJSON(for:)`, add a case to the switch so it still compiles, right after `case .passthrough: return nil`:
```swift
        case .answer:
            return nil   // answers use the PreToolUse envelope — see answerStdoutJSON(_:originalToolInput:)
```

- [ ] **Step 3: Add the PreToolUse answer encoder**

Append to `DecisionEncoder` (inside the enum, after `stdoutJSON`):
```swift
    /// Encodes an AskUserQuestion answer for the `PreToolUse` hook stdout contract:
    /// `permissionDecision:"allow"` + `updatedInput` = the original tool_input merged with `answers`.
    public static func answerStdoutJSON(_ answers: [String: String], originalToolInput: Data?) -> Data? {
        var updatedInput: [String: Any] = [:]
        if let originalToolInput,
           let obj = try? JSONSerialization.jsonObject(with: originalToolInput) as? [String: Any] {
            updatedInput = obj
        }
        updatedInput["answers"] = answers
        let root: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "updatedInput": updatedInput
            ]
        ]
        return try? JSONSerialization.data(withJSONObject: root)
    }
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: builds successfully.

- [ ] **Step 5: Run existing tests**

Run: `swift test 2>&1 | tail -20`
Expected: existing tests pass (DecisionEncoderTests still cover allow/deny/passthrough unchanged). If DecisionEncoderTests has an exhaustive `switch` over `Decision`, update that existing test to include a `.answer` arm — do not add new test methods.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/Decision.swift Sources/ClaudeNotchCore/Domain/DecisionEncoder.swift
git commit
```
Message subject: `feat: add Decision.answer and PreToolUse answer encoder`

---

### Task B2: `DecisionKind.question` model + question card UI

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/Decision.swift` (QuestionSpec, DecisionKind.question, DecisionRequest.from)
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift` (DecisionCardView question case)

**Interfaces:**
- Consumes: `Decision.answer(answers:)` (B1); `NotchViewModel.onAnswerInTerminal` (C2).
- Produces: `QuestionOption`, `QuestionSpec`, `DecisionKind.question(questions: [QuestionSpec])`.

- [ ] **Step 1: Add the question value types**

In `Decision.swift`, above `DecisionKind`, add:
```swift
public struct QuestionOption: Sendable, Equatable {
    public let label: String
    public let description: String?
    public init(label: String, description: String?) { self.label = label; self.description = description }
}

public struct QuestionSpec: Sendable, Equatable {
    public let question: String
    public let header: String?
    public let options: [QuestionOption]
    public let multiSelect: Bool
    public init(question: String, header: String?, options: [QuestionOption], multiSelect: Bool) {
        self.question = question; self.header = header; self.options = options; self.multiSelect = multiSelect
    }
}
```
Then add the case to `DecisionKind`:
```swift
public enum DecisionKind: Sendable, Equatable {
    case toolPermission(tool: String, preview: ToolPreview)
    case planApproval(text: String)
    case question(questions: [QuestionSpec])
}
```

- [ ] **Step 2: Parse AskUserQuestion in `DecisionRequest.from`**

In `Decision.swift`, replace the body of `from(_:id:)` with:
```swift
    static func from(_ event: HookEvent, id: String) -> DecisionRequest? {
        guard let tool = event.toolName else { return nil }
        let sessionKey = SessionKey.derive(env: event.env, sessionID: event.sessionID)
        let input = event.toolInputDict ?? [:]
        let kind: DecisionKind
        if tool == "AskUserQuestion" {
            kind = .question(questions: Self.parseQuestions(input))
        } else if tool == "ExitPlanMode" {
            kind = .planApproval(text: (input["plan"] as? String) ?? "")
        } else {
            kind = .toolPermission(tool: tool, preview: ToolInputRenderer.render(tool: tool, input: input))
        }
        return DecisionRequest(id: id, sessionKey: sessionKey, kind: kind, receivedAt: event.receivedAt)
    }

    private static func parseQuestions(_ input: [String: Any]) -> [QuestionSpec] {
        let raw = (input["questions"] as? [[String: Any]]) ?? []
        return raw.map { q in
            let opts = ((q["options"] as? [[String: Any]]) ?? []).map {
                QuestionOption(label: ($0["label"] as? String) ?? "", description: $0["description"] as? String)
            }
            return QuestionSpec(
                question: (q["question"] as? String) ?? "",
                header: q["header"] as? String,
                options: opts,
                multiSelect: (q["multiSelect"] as? Bool) ?? false
            )
        }
    }
```

- [ ] **Step 3: Render the question card**

In `NotchViews.swift`, `DecisionCardView.body`, add a case to the `switch request.kind` (after the `.planApproval` case, before the closing brace of the switch):
```swift
            case let .question(questions):
                if let q = questions.first, questions.count == 1, !q.multiSelect {
                    if let header = q.header {
                        Text(header).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(q.question).font(.headline)
                    ForEach(Array(q.options.enumerated()), id: \.offset) { _, opt in
                        Button {
                            onDecide?(request, .answer(answers: [q.question: opt.label]))
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(opt.label).font(.system(size: 13, weight: .medium))
                                if let d = opt.description {
                                    Text(d).font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    // Multi-question or multi-select: not single-click answerable → terminal.
                    Text("Claude is asking a question").font(.headline).foregroundStyle(.purple)
                    Text("Answer this one in the terminal.").font(.caption).foregroundStyle(.secondary)
                }
```
(The shared bottom `Answer in terminal` button already covers the fallback via C2's `onAnswerInTerminal`.)

- [ ] **Step 4: Build**

Run: `swift build`
Expected: builds successfully (DecisionCardView switch is exhaustive again).

- [ ] **Step 5: Run existing tests**

Run: `swift test 2>&1 | tail -20`
Expected: existing tests pass. If DecisionTests has an exhaustive `switch` over `DecisionKind`, update that existing test to include a `.question` arm — do not add new test methods.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/Decision.swift Sources/ClaudeNotchApp/UI/NotchViews.swift
git commit
```
Message subject: `feat: model and render AskUserQuestion as a notch question card`

---

### Task B3: Install the synchronous PreToolUse hook for AskUserQuestion

**Files:**
- Modify: `Sources/ClaudeNotchCore/Install/HookInstaller.swift`

**Interfaces:**
- Consumes: existing `Spec` / `specs` machinery, bridge `decide <EventName>` route.
- Produces: a `PreToolUse` / matcher `AskUserQuestion` synchronous hook in installed settings.

- [ ] **Step 1: Add the spec**

In `HookInstaller.swift`, inside `specs`, in the `if decisionsEnabled { … }` block, append after the two `PermissionRequest` specs:
```swift
            // Synchronous PreToolUse hook JUST for AskUserQuestion, so the notch can answer it
            // in-place via updatedInput.answers. Coexists with the async PreToolUse "*" monitor.
            s.append(Spec(event: "PreToolUse", matcher: "AskUserQuestion",
                          args: "decide PreToolUse", isAsync: false, timeout: 600))
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds successfully.

- [ ] **Step 3: Run existing tests**

Run: `swift test 2>&1 | tail -20`
Expected: existing tests pass. If `HookInstallerTests` asserts an exact set/shape of installed hooks, update those existing assertions to include the new `PreToolUse`/`AskUserQuestion` group — do not add new test methods.

- [ ] **Step 4: Inspect generated settings**

Run the app once (so it reinstalls hooks) or call the installer path, then:
```bash
python3 -c "import json;d=json.load(open('$HOME/.claude/settings.json'));print(json.dumps(d.get('hooks',{}).get('PreToolUse',[]),indent=2))"
```
Expected: two PreToolUse groups — `matcher:"*"` (async monitor) and `matcher:"AskUserQuestion"` (synchronous, `"command"` ends with `decide PreToolUse`, `timeout:600`, no `async`).

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Install/HookInstaller.swift
git commit
```
Message subject: `feat: install synchronous PreToolUse hook for AskUserQuestion`

---

### Task B4: Route the decision and encode the answer

**Files:**
- Modify: `Sources/ClaudeNotchApp/Transport/HookServer.swift`
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift`

**Interfaces:**
- Consumes: `DecisionRequest.from` question parsing (B2), `DecisionEncoder.answerStdoutJSON` (B1), `Decision.answer` (B1).
- Produces: end-to-end AskUserQuestion answer-in-place.

- [ ] **Step 1: Encode `.answer` with the original tool_input in `HookServer`**

In `HookServer.respond`, replace the `/decide/` branch:
```swift
        if path.hasPrefix("/decide/"), let onDecision {
            // Hold the connection open until a decision resolves; then write the JSON body.
            onDecision(event) { [weak self] decision in
                let body: Data
                if case let .answer(answers) = decision {
                    body = DecisionEncoder.answerStdoutJSON(answers, originalToolInput: event.toolInput) ?? Data()
                } else {
                    body = DecisionEncoder.stdoutJSON(for: decision) ?? Data()   // passthrough → empty
                }
                self?.write(conn, status: "200 OK", body: body)
            }
        } else {
```

- [ ] **Step 2: Skip AskUserQuestion on the PermissionRequest path**

In `AppCoordinator.resolveDecision`, add this guard as the first statement (before the `guard let request …`):
```swift
        // AskUserQuestion is answered via its own synchronous PreToolUse decide hook. In normal
        // permission mode a PermissionRequest may ALSO fire for it — pass through so we don't
        // show a stray allow/deny card on top of the question card.
        if event.name == .permissionRequest, event.toolName == "AskUserQuestion" {
            return complete(.passthrough)
        }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds successfully.

- [ ] **Step 4: Run existing tests**

Run: `swift test 2>&1 | tail -20`
Expected: existing tests pass.

- [ ] **Step 5: Manual e2e — answer-in-place**

1. Rebuild and run the app. Use the menu-bar **Reinstall hooks**. Start a fresh Claude session (so it re-reads settings).
2. Ask Claude to use AskUserQuestion (e.g. *"Use the AskUserQuestion tool to ask me to pick a color, Red or Blue."*).
3. Expected: the notch shows the real question + one button per option. Clicking an option makes Claude proceed with that answer (`User answered Claude's questions: … → …`) **without any terminal interaction**.
4. Click **Answer in terminal** on a different question run: the terminal focuses and Claude's own menu appears.

- [ ] **Step 6: Manual e2e — no double-prompt in normal mode**

Reuse the `/tmp/auq-verify` harness idea but against the real app in **normal** permission mode (not bypass): trigger AskUserQuestion in a normal session and confirm only the question card appears (no separate Deny/Allow card). If a stray card appears, the Step 2 guard needs the event name/tool check adjusted — investigate and fix before committing.

- [ ] **Step 7: Commit**

```bash
git add Sources/ClaudeNotchApp/Transport/HookServer.swift Sources/ClaudeNotchApp/AppCoordinator.swift
git commit
```
Message subject: `feat: answer AskUserQuestion in-place from the notch`

---

## Finalization

- [ ] **Step 1: Full build + test sweep**

Run: `swift build && swift test 2>&1 | tail -30`
Expected: green.

- [ ] **Step 2: Commit the design + this plan if not already tracked**

```bash
git add docs/superpowers/specs/2026-07-23-claudenotch-interaction-fixes-design.md docs/superpowers/plans/2026-07-23-claudenotch-interaction-fixes.md
git commit
```
Message subject: `docs: add interaction-fixes design + implementation plan`
(Only if these are still untracked/modified.)

- [ ] **Step 3: Hand back for review / merge** per `superpowers:finishing-a-development-branch`.

---

## Self-Review (completed while writing)

- **Spec coverage:** C1+C2 = jump wiring; C3 = tmux/TCC investigation; A1 = hover-to-expand; B1 = Decision.answer + encoder; B2 = question model + card; B3 = hook install; B4 = routing + PermissionRequest exclusion + fallback. All spec sections map to a task.
- **Placeholder scan:** no TBD/vague steps; every code step shows full code; investigation steps (C3) list concrete commands and decision criteria.
- **Type consistency:** `Decision.answer(answers: [String: String])`, `DecisionEncoder.answerStdoutJSON(_:originalToolInput:)`, `DecisionKind.question(questions:)`, `QuestionSpec`/`QuestionOption`, `SessionStore.session(forKey:)`, `NotchController.onAnswerInTerminal` — names used identically across B1↔B4, C1↔C2, C2↔B2. Encoder consumes `event.toolInput` (`Data?`), which matches `HookEvent.toolInput`.
- **No new tests:** all verification is build + existing suite + manual e2e; existing tests updated only where a covered contract (enum exhaustiveness, installed-hook shape) changes.
