#!/usr/bin/env bash
# Demo driver for ClaudeNotch.
#
# POSTs synthetic hook events to the running app so you can eyeball the notch
# (hover -> expanded list), the per-state accent colors, and the completion
# sounds WITHOUT needing a real `claude` session.
#
# Requires the app to be running (`swift run ClaudeNotchApp`) so that bridge.json
# exists with the live {port, token}.
#
# NOTE: click-to-jump can't be tested this way — these rows carry fake iTerm
# UUIDs with no matching pane, so a click will fall back rather than jump. Use a
# real `claude` session in iTerm2 to test click-to-jump + the TCC prompt.
set -euo pipefail

CFG="$HOME/Library/Application Support/ClaudeNotch/bridge.json"
[ -f "$CFG" ] || { echo "bridge.json not found at:"; echo "  $CFG"; echo "Is ClaudeNotchApp running? (swift run ClaudeNotchApp)"; exit 1; }

# bridge.json is simple flat JSON: {"port":NNN,"token":"..."} — parse without deps.
PORT=$(sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$CFG")
TOKEN=$(sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CFG")
[ -n "$PORT" ] && [ -n "$TOKEN" ] || { echo "Could not parse port/token from $CFG"; cat "$CFG"; exit 1; }
echo "Using 127.0.0.1:$PORT"

post() { # post <EventName> <json-body>
  curl -sS -o /dev/null -w "  %{http_code}  $1\n" \
    -X POST "http://127.0.0.1:$PORT/hook/$1" \
    -H "X-ClaudeNotch-Token: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$2"
}

echo "-> 3 active sessions (working / needsPermission / needsInput):"
post SessionStart  '{"session_id":"demo-A","cwd":"/Users/you/alpha","env":{"ITERM_SESSION_ID":"w0t0p0:DEMO-A"}}'
post SessionStart  '{"session_id":"demo-B","cwd":"/Users/you/bravo","env":{"ITERM_SESSION_ID":"w0t1p0:DEMO-B"}}'
post SessionStart  '{"session_id":"demo-C","cwd":"/Users/you/charlie","env":{"ITERM_SESSION_ID":"w0t2p0:DEMO-C"}}'
sleep 0.3
post PreToolUse    '{"session_id":"demo-A","tool_name":"Edit","env":{"ITERM_SESSION_ID":"w0t0p0:DEMO-A"}}'
post Notification  '{"session_id":"demo-B","matcher":"permission_prompt","env":{"ITERM_SESSION_ID":"w0t1p0:DEMO-B"}}'
post Notification  '{"session_id":"demo-C","matcher":"needs_input","env":{"ITERM_SESSION_ID":"w0t2p0:DEMO-C"}}'

echo
echo "Now HOVER the notch: you should see 3 rows — alpha (🔵 working · Edit),"
echo "bravo (🟠 needs permission), charlie (needs input)."
if [ -t 0 ]; then
  read -rp "Press Enter to fire a completion (Glass) + a failure (Basso)... " _
else
  echo "(no TTY; firing completion/failure in 4s)"; sleep 4
fi

echo "-> completion + failure (listen for Glass then Basso):"
post Stop         '{"session_id":"demo-A","env":{"ITERM_SESSION_ID":"w0t0p0:DEMO-A"}}'
post StopFailure  '{"session_id":"demo-C","env":{"ITERM_SESSION_ID":"w0t2p0:DEMO-C"}}'
echo
echo "Final: alpha ✓ done, charlie ✗ failed, bravo still awaiting permission."
echo "Done- and failed- rows show only in the hovered/expanded list, not the pill."
