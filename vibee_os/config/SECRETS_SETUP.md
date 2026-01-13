# Vibee OS Secrets Setup

## Quick Start

### 1. Set Environment Variables

Create a `.env.local` file (gitignored) or export directly:

```bash
# DeepSeek (verified working)
export DEEPSEEK_API_KEY="your-key-here"

# Other providers (optional)
export ANTHROPIC_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"
export GOOGLE_API_KEY="your-key-here"
```

### 2. Verify Setup

```bash
# Test DeepSeek connection
curl -s https://api.deepseek.com/v1/models \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" | head -5
```

Expected output:
```json
{"object":"list","data":[{"id":"deepseek-chat"...
```

### 3. Use in Vibee OS

All configs reference secrets via `${VAR}` syntax:

```yaml
deepseek:
  api_key: "${DEEPSEEK_API_KEY}"
```

The secret is resolved at runtime, never stored in code.

## Security Rules

1. **NEVER** hardcode API keys in `.vibee` files
2. **NEVER** commit `.env` or `.env.local` files
3. **ALWAYS** use `${VAR}` references
4. **ALWAYS** keep `.gitignore` updated

## Available Providers

| Provider | Env Variable | Status |
|----------|--------------|--------|
| DeepSeek | `DEEPSEEK_API_KEY` | ✅ Verified |
| Anthropic | `ANTHROPIC_API_KEY` | Configure |
| OpenAI | `OPENAI_API_KEY` | Configure |
| Google | `GOOGLE_API_KEY` | Configure |

## Production Setup

For production, use proper secret management:

- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- GCP Secret Manager

See `kernel/security/secrets_manager.vibee` for full documentation.
