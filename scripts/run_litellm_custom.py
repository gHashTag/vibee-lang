import litellm
import os
import sys
import asyncio
sys.setrecursionlimit(2000)

from litellm.proxy.proxy_server import app, initialize
import uvicorn

# Store original completion function
_original_acompletion = litellm.acompletion

# Monkey patch acompletion to enforce max_tokens limit for Eden AI
async def list_model_wrapper(*args, **kwargs):
    # Cap max_tokens if present
    if 'max_tokens' in kwargs:
        try:
            mt = int(kwargs['max_tokens'])
            if mt > 16384:
                # print(f"🐒 MonkeyPatch: Capping max_tokens from {mt} to 16384")
                kwargs['max_tokens'] = 16384
        except:
            pass
            
    # Call original
    return await _original_acompletion(*args, **kwargs)

# Apply patch
litellm.acompletion = list_model_wrapper

# Initialize with config
config_path = "/Users/playra/vibee-lang/config/eden_config.yaml"
os.environ["LITELLM_CONFIG_PATH"] = config_path

print(f"🚀 Initializing LiteLLM with config: {config_path}")

# Run async initialize
asyncio.run(initialize(config=config_path))

if __name__ == "__main__":
    # Load secrets
    if os.path.exists("/Users/playra/vibee-lang/.env.local"):
        try:
            with open("/Users/playra/vibee-lang/.env.local") as f:
                for line in f:
                    if "=" in line and not line.strip().startswith("#"):
                        k, v = line.strip().split("=", 1)
                        os.environ[k] = v
        except Exception as e:
            print(f"❌ Error loading secrets: {e}")

    # Bind to 0.0.0.0:4000
    uvicorn.run(app, host="0.0.0.0", port=4000)
