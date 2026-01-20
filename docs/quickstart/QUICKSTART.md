# VIBEE Terminal Agent - Quick Start

## Installation

```bash
# Clone repository
git clone https://github.com/gHashTag/vibee-lang.git
cd vibee-lang

# Build compiler
cd src/vibeec && zig build && cd ../..

# Run
./bin/vibeec help
```

## Commands

| Command | Description |
|---------|-------------|
| `vibeec help` | Show help |
| `vibeec version` | Show version |
| `vibeec config` | Show API configuration |
| `vibeec agent` | Show agent status |
| `vibeec chat` | Start interactive AI chat |
| `vibeec gen <file.vibee>` | Generate .zig from spec |
| `vibeec pas` | Show PAS DAEMONS patterns |
| `vibeec phi` | Show sacred constants |
| `vibeec eval "expr"` | Evaluate ternary logic |

## AI Configuration

VIBEE supports three AI providers:

### Option 1: Anthropic Claude (recommended)

```bash
export ANTHROPIC_API_KEY=sk-ant-your-key-here
vibeec chat
```

### Option 2: OpenAI GPT

```bash
export OPENAI_API_KEY=sk-your-key-here
vibeec chat
```

### Option 3: Ollama (local, free)

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Start server
ollama serve

# Pull model
ollama pull llama3.2

# Run chat
vibeec chat
```

## Check Configuration

```bash
vibeec config
```

Without API key:
```
  ⚠️  NO API KEY CONFIGURED
```

With API key:
```
  ANTHROPIC_API_KEY: sk-ant-***
```

## Offline Mode

Without an API key, you can still use:

```bash
vibeec gen specs/tri/terminal_agent.vibee  # Generate code
vibeec pas                                   # PAS patterns
vibeec phi                                   # Sacred constants
vibeec eval "△ ∧ ○"                         # Ternary logic
```

## Chat Commands

| Command | Description |
|---------|-------------|
| `/help` | Show commands |
| `/quit` | Exit chat |
| `/pas` | PAS patterns |
| `/phi` | Sacred constants |

## Ternary Logic (Kleene K₃)

```
△ = TRUE    ○ = UNKNOWN    ▽ = FALSE
```

## Sacred Formula

```
V = n × 3^k × π^m × φ^p × e^q
φ² + 1/φ² = 3
999 = 3³ × 37 (PHOENIX)
```
