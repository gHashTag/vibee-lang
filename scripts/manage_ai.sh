#!/bin/bash

CONFIG_DIR="/Users/playra/vibee-lang/config"
EDEN_CONFIG="$CONFIG_DIR/eden_config.yaml"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
PROXY_LOG="/tmp/litellm_eden.log"

case "$1" in
  "eden")
    echo "🚀 Switching to Eden AI (Qwen)..."
    # Load secrets
    if [ -f "/Users/playra/vibee-lang/.env.local" ]; then
      set -a; source "/Users/playra/vibee-lang/.env.local"; set +a
    else
      echo "❌ Error: /Users/playra/vibee-lang/.env.local not found!"
      exit 1
    fi
    
    # Kill existing proxies if any
    pkill -f "litellm --config $EDEN_CONFIG" 2>/dev/null
    pkill -f "python3 /Users/playra/vibee-lang/scripts/token_fixer.py" 2>/dev/null
    pkill -f "run_litellm_custom.py" 2>/dev/null
    
    # Start Custom LiteLLM Runner on port 4000
    nohup /opt/homebrew/bin/python3.10 /Users/playra/vibee-lang/scripts/run_litellm_custom.py > "/tmp/litellm_eden.log" 2>&1 &
    
    # Wait for proxy to start
    echo "⏳ Waiting for Eden AI proxy to start..."
    sleep 5
    
    # Update settings
    sed -i.bak 's|"ANTHROPIC_BASE_URL": ".*"|"ANTHROPIC_BASE_URL": "http://localhost:4000"|g' "$CLAUDE_SETTINGS"
    echo "✅ Switched to Eden AI (Custom Runner: http://localhost:4000)"
    ;;
    
  "zai")
    pkill -f "litellm --config $EDEN_CONFIG" 2>/dev/null
    pkill -f "python3 /Users/playra/vibee-lang/scripts/token_fixer.py" 2>/dev/null
    
    # Update settings
    sed -i.bak 's|"ANTHROPIC_BASE_URL": ".*"|"ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic"|g' "$CLAUDE_SETTINGS"
    echo "✅ Switched to Z.AI (Remote: https://api.z.ai/api/anthropic)"
    ;;
    
  "status")
    CUR_URL=$(grep "ANTHROPIC_BASE_URL" "$CLAUDE_SETTINGS" | cut -d'"' -f4)
    echo "Current Provider URL: $CUR_URL"
    if pgrep -f "run_litellm_custom.py" > /dev/null; then
      echo "LiteLLM Proxy: [RUNNING]"
    else
      echo "LiteLLM Proxy: [STOPPED]"
    fi
    ;;
    
  *)
    echo "Usage: $0 {eden|zai|status}"
    exit 1
    ;;
esac
