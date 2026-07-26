#!/bin/bash
set -e

echo "=========================================="
echo "  ClaudeNotch End-to-End Test Suite  "
echo "=========================================="
echo ""

# 1. Run unit tests
echo "[1/4] Running Unit Tests (swift test)..."
swift test
echo "✅ Unit tests passed!"
echo ""

# Get active bridge config
CONFIG_FILE="$HOME/Library/Application Support/NotchDeck/bridge.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ NotchDeckApp is not running. Please start NotchDeckApp first."
  exit 1
fi

PORT=$(grep -o '"port":[0-9]*' "$CONFIG_FILE" | cut -d: -f2)
TOKEN=$(grep -o '"token":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)

echo "Connected to NotchDeckApp on port $PORT."
echo ""

NOTCH_PID=$(pgrep NotchDeckApp | head -n 1)
if [ -z "$NOTCH_PID" ]; then
  echo "❌ NotchDeckApp process not found."
  exit 1
fi

MCP_BIN="$HOME/Applications/MacControlMCP.app/Contents/MacOS/MacControlMCP"

# Helper python function to extract button center coordinates by title substring
get_coords() {
  local elements_json="$1"
  local target_title="$2"
  python3 -c '
import sys, json
data = json.loads(sys.argv[1])
target = sys.argv[2].lower()
elements = data.get("result", {}).get("structuredContent", {}).get("elements", [])
for el in elements:
    title = (el.get("title") or "").lower()
    if target in title:
        pos = el.get("position", {})
        size = el.get("size", {})
        cx = pos.get("x", 0) + size.get("width", 0) / 2
        cy = pos.get("y", 0) + size.get("height", 0) / 2
        print(f"{int(cx)} {int(cy)}")
        sys.exit(0)
print("0 0")
' "$elements_json" "$target_title"
}

# 2. Test AskUserQuestion Hook
echo "[2/4] Testing Scenario Q1: AskUserQuestion & Option Selection..."
QUESTION_PAYLOAD='{"session_id":"e2e-test-q1","cwd":"'$(pwd)'","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"E2E Test Question?","header":"E2E Test","multiSelect":false,"options":[{"label":"Option Alpha","description":"Test A"},{"label":"Option Beta","description":"Test B"}]}]}}'

echo "$QUESTION_PAYLOAD" | swift run notch-bridge decide PreToolUse > /tmp/e2e_q1_out.json 2>&1 &
BRIDGE_PID=$!

sleep 2

ELEMENTS_JSON=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"find_elements","arguments":{"pid":'$NOTCH_PID'}}}' | "$MCP_BIN")

if echo "$ELEMENTS_JSON" | grep -q "Option Alpha"; then
  echo "   - Question Card rendered on screen."
else
  echo "❌ Question Card failed to render."
  exit 1
fi

COORDS=$(get_coords "$ELEMENTS_JSON" "Option Alpha")
CX=$(echo $COORDS | awk '{print $1}')
CY=$(echo $COORDS | awk '{print $2}')
if [ "$CX" -eq 0 ]; then CX=756; CY=143; fi

echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"click","arguments":{"x":'$CX',"y":'$CY'}}}' | "$MCP_BIN" > /dev/null

wait $BRIDGE_PID || true

if grep -q "Option Alpha" /tmp/e2e_q1_out.json; then
  echo "✅ Scenario Q1 Passed: Option clicked and decision contract returned!"
else
  echo "❌ Scenario Q1 Failed: stdout payload missing answer."
  cat /tmp/e2e_q1_out.json
  exit 1
fi
echo ""

# 3. Test PermissionRequest Hook
echo "[3/4] Testing Scenario P1: PermissionRequest (Allow)..."
PERM_PAYLOAD='{"session_id":"e2e-test-p1","cwd":"'$(pwd)'","tool_name":"Bash","tool_input":{"command":"git status"}}'

echo "$PERM_PAYLOAD" | swift run notch-bridge decide PermissionRequest > /tmp/e2e_p1_out.json 2>&1 &
BRIDGE_PID=$!

sleep 2

ELEMENTS_JSON=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"find_elements","arguments":{"pid":'$NOTCH_PID'}}}' | "$MCP_BIN")

if echo "$ELEMENTS_JSON" | grep -q "Permission · Bash"; then
  echo "   - Permission Card rendered on screen."
else
  echo "❌ Permission Card failed to render."
  exit 1
fi

COORDS=$(get_coords "$ELEMENTS_JSON" "Allow")
CX=$(echo $COORDS | awk '{print $1}')
CY=$(echo $COORDS | awk '{print $2}')
if [ "$CX" -eq 0 ]; then CX=756; CY=276; fi

echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"click","arguments":{"x":'$CX',"y":'$CY'}}}' | "$MCP_BIN" > /dev/null

wait $BRIDGE_PID || true

if grep -q '"behavior":"allow"' /tmp/e2e_p1_out.json; then
  echo "✅ Scenario P1 Passed: Permission allowed and contract returned!"
else
  echo "❌ Scenario P1 Failed."
  cat /tmp/e2e_p1_out.json
  exit 1
fi
echo ""

# 4. Verify Final UI State
echo "[4/4] Verifying Final UI Collapse & State..."
sleep 1
FINAL_ELEMENTS=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"find_elements","arguments":{"pid":'$NOTCH_PID'}}}' | "$MCP_BIN")

if echo "$FINAL_ELEMENTS" | grep -q "Option Alpha" || echo "$FINAL_ELEMENTS" | grep -q "Permission · Bash"; then
  echo "❌ UI failed to collapse: decision cards still present."
  exit 1
else
  echo "✅ Scenario H1 Passed: All decision cards cleared and Notch UI collapsed smoothly!"
fi

echo ""
echo "=========================================="
echo "  🎉 ALL E2E TEST SCENARIOS PASSED!  "
echo "=========================================="
