# IGLA MCP Server Guide

Model Context Protocol server for IGLA SWE Agent integration with Claude, Cursor, and other MCP clients.

## Quick Start

```bash
# Test the server
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python3 mcp/igla_server.py

# List available tools
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | python3 mcp/igla_server.py
```

## Claude Desktop Integration

Add to `~/.config/claude/claude_desktop_config.json` (Linux) or `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS):

```json
{
  "mcpServers": {
    "igla-swe-agent": {
      "command": "python3",
      "args": ["/path/to/vibee-lang/mcp/igla_server.py"]
    }
  }
}
```

Restart Claude Desktop to load the server.

## Available Tools

### `generate_patch`

Generate a code patch to fix a GitHub issue.

```json
{
  "name": "generate_patch",
  "arguments": {
    "repo": "django/django",
    "issue_description": "Fix username validator to reject trailing newlines",
    "hints": "Use \\Z instead of $ in regex"
  }
}
```

### `run_tests`

Run tests in a repository.

```json
{
  "name": "run_tests",
  "arguments": {
    "repo_path": "/tmp/django",
    "tests": ["tests/auth_tests/test_validators.py"],
    "timeout": 300
  }
}
```

### `analyze_code`

Analyze code for issues or complexity.

```json
{
  "name": "analyze_code",
  "arguments": {
    "file_path": "/path/to/file.py",
    "analysis_type": "complexity"
  }
}
```

Analysis types: `complexity`, `issues`, `patterns`, `dependencies`

### `git_operations`

Perform git operations.

```json
{
  "name": "git_operations",
  "arguments": {
    "operation": "clone",
    "repo_url": "https://github.com/django/django.git",
    "repo_path": "/tmp/django"
  }
}
```

Operations: `clone`, `checkout`, `apply_patch`, `diff`, `status`

### `swe_bench`

Interact with SWE-bench dataset.

```json
{
  "name": "swe_bench",
  "arguments": {
    "action": "list",
    "limit": 10
  }
}
```

Actions: `list`, `get`, `evaluate`

### `search_code`

Search for code patterns.

```json
{
  "name": "search_code",
  "arguments": {
    "repo_path": "/tmp/django",
    "query": "def validate",
    "file_pattern": "*.py"
  }
}
```

## Available Resources

| URI | Description |
|-----|-------------|
| `swe-bench://instances` | SWE-bench instances |
| `igla://config` | IGLA configuration |
| `igla://stats` | Module and test statistics |

## Available Prompts

### `swe_fix`

Generate a fix for a software engineering issue.

```json
{
  "name": "swe_fix",
  "arguments": {
    "repo": "django/django",
    "issue": "Username validator allows trailing newlines"
  }
}
```

### `code_review`

Review code changes.

```json
{
  "name": "code_review",
  "arguments": {
    "diff": "diff --git a/file.py..."
  }
}
```

## Protocol Details

- **Protocol Version**: 2024-11-05
- **Transport**: stdio (stdin/stdout)
- **Format**: JSON-RPC 2.0

## Example Session

```bash
# Initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' | python3 mcp/igla_server.py

# List SWE-bench instances
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"swe_bench","arguments":{"action":"list","limit":5}}}' | python3 mcp/igla_server.py

# Get specific instance
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"swe_bench","arguments":{"action":"get","instance_id":"django__django-11099"}}}' | python3 mcp/igla_server.py

# Read IGLA stats
echo '{"jsonrpc":"2.0","id":4,"method":"resources/read","params":{"uri":"igla://stats"}}' | python3 mcp/igla_server.py
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    IGLA MCP Server                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Tools     │    │  Resources  │    │   Prompts   │         │
│  │  (6 tools)  │    │ (3 resources)│   │ (2 prompts) │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                  │                  │                 │
│         ▼                  ▼                  ▼                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │              MCP Protocol Handler                    │       │
│  │           (JSON-RPC 2.0 over stdio)                  │       │
│  └─────────────────────────────────────────────────────┘       │
│                           │                                     │
│                           ▼                                     │
│  ┌─────────────────────────────────────────────────────┐       │
│  │              IGLA SWE Agent Core                     │       │
│  │         (32 modules, 294 tests)                      │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Statistics

| Component | Count |
|-----------|-------|
| Tools | 6 |
| Resources | 3 |
| Prompts | 2 |
| IGLA Modules | 34 |
| IGLA Tests | 294 |

---

**φ² + 1/φ² = 3 | PHOENIX = 999**
