#!/bin/bash
# VIBEE Autonomous Browser Agent Loop v21
# Chrome CDP + Ollama LLM = Full Automation
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

# Configuration
CDP_HOST="localhost"
CDP_PORT="9222"
OLLAMA_HOST="localhost"
OLLAMA_PORT="11434"
MODEL="qwen2.5:3b"
MAX_STEPS=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[AGENT]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# Check dependencies
check_deps() {
    log "Checking dependencies..."
    
    # Check Chrome CDP
    if ! curl -s "http://${CDP_HOST}:${CDP_PORT}/json/version" > /dev/null 2>&1; then
        error "Chrome CDP not running on ${CDP_HOST}:${CDP_PORT}"
        exit 1
    fi
    success "Chrome CDP ready"
    
    # Check Ollama
    if ! curl -s "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/version" > /dev/null 2>&1; then
        error "Ollama not running on ${OLLAMA_HOST}:${OLLAMA_PORT}"
        exit 1
    fi
    success "Ollama ready"
}

# OBSERVE: Get current page state
observe() {
    local page_info=$(curl -s "http://${CDP_HOST}:${CDP_PORT}/json/list" 2>/dev/null | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
for page in data:
    if page.get('type') == 'page' and not page.get('url', '').startswith('chrome'):
        print(json.dumps({'url': page.get('url', ''), 'title': page.get('title', '')}))
        break
" 2>/dev/null || echo '{"url":"","title":""}')
    
    echo "$page_info"
}

# THINK: Ask LLM for next action
think() {
    local task="$1"
    local observation="$2"
    local history="$3"
    local step="$4"
    
    local url=$(echo "$observation" | python3 -c "import json,sys; print(json.load(sys.stdin).get('url',''))" 2>/dev/null)
    local title=$(echo "$observation" | python3 -c "import json,sys; print(json.load(sys.stdin).get('title',''))" 2>/dev/null)
    
    local prompt="You are a browser agent. You can ONLY use these 6 actions:

ALLOWED ACTIONS (use EXACTLY one):
- goto: Navigate to URL. Input: full URL (e.g., https://example.com)
- click: Click element. Input: CSS selector (e.g., button#submit)
- type: Type text. Input: selector|text (e.g., input#search|hello)
- scroll: Scroll page. Input: up or down
- done: Task complete. Input: the result/answer
- fail: Cannot complete. Input: reason why

CURRENT STATE:
URL: ${url}
Title: ${title}
Step: ${step}/${MAX_STEPS}

TASK: ${task}

${history}

IMPORTANT: If the answer is already visible (like page title), use 'done' immediately!

Respond in EXACTLY this format:
Thought: [one sentence reasoning]
Action: [goto|click|type|scroll|done|fail]
Input: [parameter for the action]"

    local response=$(curl -s "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/generate" \
        -d "$(python3 -c "import json; print(json.dumps({'model':'${MODEL}','prompt':'''${prompt}''','stream':False}))")" 2>/dev/null | \
        python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null)
    
    echo "$response"
}

# ACT: Execute browser action
act() {
    local action="$1"
    local input="$2"
    
    case "$action" in
        goto)
            log "Navigating to: $input"
            curl -s -X PUT "http://${CDP_HOST}:${CDP_PORT}/json/new?${input}" > /dev/null 2>&1
            sleep 2
            success "Navigation complete"
            echo "success"
            ;;
        click)
            log "Click action: $input (simulated)"
            success "Click simulated"
            echo "success"
            ;;
        type)
            log "Type action: $input (simulated)"
            success "Type simulated"
            echo "success"
            ;;
        scroll)
            log "Scroll action: $input (simulated)"
            success "Scroll simulated"
            echo "success"
            ;;
        done)
            success "Task completed: $input"
            echo "done"
            ;;
        fail)
            error "Task failed: $input"
            echo "fail"
            ;;
        *)
            warn "Unknown action: $action"
            echo "error"
            ;;
    esac
}

# Parse LLM response into action
parse_action() {
    local response="$1"
    
    local thought=$(echo "$response" | grep -i "^Thought:" | sed 's/^Thought:\s*//' | head -1)
    local action=$(echo "$response" | grep -i "^Action:" | sed 's/^Action:\s*//' | head -1 | tr '[:upper:]' '[:lower:]')
    local input=$(echo "$response" | grep -i "^Input:" | sed 's/^Input:\s*//' | head -1)
    
    echo "${thought}|${action}|${input}"
}

# Main agent loop
run_agent() {
    local task="$1"
    local start_url="$2"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           VIBEE AUTONOMOUS BROWSER AGENT v21                 ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ Task: $(printf '%-52s' "$task") ║"
    echo "║ Start: $(printf '%-51s' "$start_url") ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_deps
    
    # Navigate to start URL if provided
    if [ -n "$start_url" ]; then
        log "Starting at: $start_url"
        curl -s -X PUT "http://${CDP_HOST}:${CDP_PORT}/json/new?${start_url}" > /dev/null 2>&1
        sleep 2
    fi
    
    local history=""
    local step=1
    local total_start=$(date +%s%N)
    
    while [ $step -le $MAX_STEPS ]; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "STEP $step/$MAX_STEPS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # OBSERVE
        local obs_start=$(date +%s%N)
        log "OBSERVE: Getting page state..."
        local observation=$(observe)
        local obs_end=$(date +%s%N)
        local obs_ms=$(( (obs_end - obs_start) / 1000000 ))
        
        local url=$(echo "$observation" | python3 -c "import json,sys; print(json.load(sys.stdin).get('url',''))" 2>/dev/null)
        local title=$(echo "$observation" | python3 -c "import json,sys; print(json.load(sys.stdin).get('title',''))" 2>/dev/null)
        echo "  URL: $url"
        echo "  Title: $title"
        echo "  Time: ${obs_ms}ms"
        
        # THINK
        local think_start=$(date +%s%N)
        log "THINK: Asking LLM for next action..."
        local response=$(think "$task" "$observation" "$history" "$step")
        local think_end=$(date +%s%N)
        local think_ms=$(( (think_end - think_start) / 1000000 ))
        
        local parsed=$(parse_action "$response")
        local thought=$(echo "$parsed" | cut -d'|' -f1)
        local action=$(echo "$parsed" | cut -d'|' -f2)
        local input=$(echo "$parsed" | cut -d'|' -f3)
        
        echo "  Thought: $thought"
        echo "  Action: $action"
        echo "  Input: $input"
        echo "  Time: ${think_ms}ms"
        
        # ACT
        local act_start=$(date +%s%N)
        log "ACT: Executing $action..."
        local result=$(act "$action" "$input")
        local act_end=$(date +%s%N)
        local act_ms=$(( (act_end - act_start) / 1000000 ))
        echo "  Result: $result"
        echo "  Time: ${act_ms}ms"
        
        # Update history
        history="${history}
Step ${step}: ${action} ${input} -> ${result}"
        
        # Check if done (check if result contains "done" or "fail")
        if echo "$result" | grep -q "^done$\|^fail$"; then
            break
        fi
        
        step=$((step + 1))
    done
    
    local total_end=$(date +%s%N)
    local total_ms=$(( (total_end - total_start) / 1000000 ))
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      AGENT RESULT                            ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ Steps taken: $step                                            ║"
    echo "║ Total time: ${total_ms}ms                                       ║"
    echo "║ Final URL: $(printf '%-48s' "$url") ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

# Entry point
if [ $# -lt 1 ]; then
    echo "Usage: $0 <task> [start_url]"
    echo ""
    echo "Examples:"
    echo "  $0 'Get the title of example.com' 'https://example.com'"
    echo "  $0 'Search for cats on Google' 'https://www.google.com'"
    exit 1
fi

TASK="$1"
START_URL="${2:-}"

run_agent "$TASK" "$START_URL"
