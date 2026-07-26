# ClaudeNotch (`NotchDeckApp`) Complete Test Suite & QA Matrix

This document outlines all end-to-end testing scenarios for `ClaudeNotch`. Use this matrix whenever implementing fixes, UI updates, or refactoring decision hooks.

---

## 1. Decision Requests & Question UI (`AskUserQuestion`)

| ID | Scenario | Trigger Payload / Action | Expected Result | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **Q1** | **Single Option Selection** | Send `AskUserQuestion` with 4 options; click Option 2 ("SQLite") | Question card closes immediately. Notch contracts to compact pill. Output stdout JSON contains `"answers": { "<question>": "SQLite" }`. | `MacControlMCP.click` + stdout check |
| **Q2** | **Keyboard Shortcut Option** | Send `AskUserQuestion`; press key `1`, `2`, `3`, or `4` | Option selected corresponding to number. Card closes and contracts to compact pill. | `MacControlMCP.press_key` |
| **Q3** | **Answer in Terminal** | Click *"Answer in terminal"* button on card | Session terminal window gets focused. Decision returns `.passthrough` (empty JSON). Card closes. | `MacControlMCP.click` |
| **Q4** | **1st Hover Post-Answer** | Answer any question, then hover cursor over compact status pill | Notch expands to session list on the **very first hover** without needing to move cursor away. | `MacControlMCP.click(x, y)` |
| **Q5** | **Multiple Queueing** | Send 2 `AskUserQuestion` requests simultaneously | First card displays with label *"1 more waiting"*. Answering Card 1 transitions immediately to Card 2. | `notch-bridge` x2 |

---

## 2. Tool Permission Requests (`PermissionRequest`)

| ID | Scenario | Trigger Payload / Action | Expected Result | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **P1** | **Allow (Once)** | Send tool permission request for `Bash`; click *"Allow"* | Card closes. Output stdout JSON contains `{"behavior": "allow"}`. | `MacControlMCP.click` |
| **P2** | **Allow for Session** | Send tool permission for `Edit`; click *"Allow for this session"* | Tool remembered. Output contains `{"behavior": "allow"}`. Next permission for `Edit` in same session auto-approves without showing card. | `notch-bridge` repeat |
| **P3** | **Deny Permission** | Send tool permission; click *"Deny"* | Card closes. Output contains `{"behavior": "deny", "message": "Denied from notch"}`. | `MacControlMCP.click` |
| **P4** | **Diff Preview Render** | Send file write/edit tool permission with lines diff | Rendered diff preview displays added (`+`) in green and removed (`-`) in red. | `MacControlMCP.capture_window` |

---

## 3. Plan Approvals (`planApproval`)

| ID | Scenario | Trigger Payload / Action | Expected Result | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **L1** | **Approve Plan** | Send plan approval payload; click *"Approve plan"* | Card closes. Output contains `{"behavior": "allow"}`. | `MacControlMCP.click` |
| **L2** | **Request Changes** | Send plan approval payload; click *"Request changes"* | Card closes. Output contains `{"behavior": "deny", "message": "Requested changes from notch"}`. | `MacControlMCP.click` |
| **L3** | **Plan Text Scrolling** | Send plan approval with >100 lines markdown text | Plan text container renders scrollbar and bottom fade gradient. | `MacControlMCP.find_elements` |

---

## 4. Presentation & Hover States

| ID | Scenario | Trigger Payload / Action | Expected Result | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **H1** | **Hover Expansion** | Hover cursor over compact status pill for >0.30s | Notch expands smoothly to show active session list (`NotchExpandedView`). | `MacControlMCP.click(pill_x, pill_y)` |
| **H2** | **Hover Exit Grace** | Move cursor outside expanded Notch for >0.25s | Notch contracts smoothly to compact pill (`NotchCompactView`). | Move cursor outside window |
| **H3** | **Zero Active Sessions** | End all active sessions (`sessionEnd` hook) | Notch hides completely (`.hidden` state). | Send `sessionEnd` hook |
| **H4** | **Active Sessions Pill** | 1+ active sessions present | Notch stays visible in menu bar as compact status pill with colored dots & count. | Check menu bar area |

---

## 5. Terminal Jumping & Menu Bar Controls

| ID | Scenario | Trigger Payload / Action | Expected Result | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **J1** | **Terminal Focus** | Click session row in expanded session list | Associated terminal window (iTerm2 / WezTerm / Kitty) is brought to front. | `MacControlMCP.click` on session row |
| **J2** | **Jump Notice** | Click session row when terminal app is closed/invalid | Red notice text *"Couldn't focus that terminal..."* displays transiently for 2.5s. | Check notice text element |
| **M1** | **Menu Bar Theme Switch** | Click menu bar icon `◗` $\rightarrow$ Theme $\rightarrow$ Select theme (e.g. *Tokyo Night*) | Entire Notch UI updates colors live matching the selected palette. | Menu item select |
| **M2** | **Hooks Install/Uninstall** | Menu bar icon `◗` $\rightarrow$ *"Uninstall hooks"* / *"Reinstall hooks"* | Config file `.claude/settings.json` is updated idempotently. | Inspect `.claude/settings.json` |

---

## Quick Simulation Command Cheat-Sheet

### Simulate Question (`AskUserQuestion`)
```bash
echo '{"session_id":"test-1","cwd":"'$(pwd)'","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Test question?","header":"QA Test","multiSelect":false,"options":[{"label":"Option A","description":"Desc A"},{"label":"Option B","description":"Desc B"}]}]}}' | swift run notch-bridge decide PreToolUse
```

### Simulate Permission Request (`PermissionRequest`)
```bash
echo '{"session_id":"test-1","cwd":"'$(pwd)'","tool_name":"Bash","tool_input":{"command":"git status"}}' | swift run notch-bridge decide PermissionRequest
```

### Simulate Plan Approval (`planApproval`)
```bash
echo '{"session_id":"test-1","cwd":"'$(pwd)'","tool_name":"ExitPlanMode","tool_input":{"plan":"1. Refactor NotchController\n2. Add tests"}}' | swift run notch-bridge decide PreToolUse
```
