#!/bin/bash
# stream_chat.sh - SSE Streaming Chat Demo
# φ² + 1/φ² = 3 | PHOENIX = 999

PORT=${1:-8001}
PROMPT=${2:-"Hello, who are you?"}
MAX_TOKENS=${3:-100}

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  iGLA Streaming Chat                                          ║"
echo "║  φ² + 1/φ² = 3 | PHOENIX = 999                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "You: $PROMPT"
echo ""
echo -n "AI: "

curl -sN -X POST "http://localhost:$PORT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":$MAX_TOKENS,\"stream\":true}" 2>&1 | \
  grep -oP '"content":"[^"]*"' | \
  sed 's/"content":"//g' | \
  sed 's/"//g' | \
  sed 's/\\n/\n/g' | \
  while IFS= read -r token; do
    printf "%s" "$token"
  done

echo ""
echo ""
