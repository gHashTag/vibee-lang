"""
FPGA.Network Inference Server

REST API and gRPC server for handling inference requests.
"""

import asyncio
import json
import uuid
from aiohttp import web
from typing import Optional

from agent.config import AgentConfig
from agent.inference import InferenceEngine, InferenceRequest


class InferenceServer:
    """HTTP/REST server for inference requests"""
    
    def __init__(self, config: AgentConfig, engine: InferenceEngine):
        self.config = config
        self.engine = engine
        self.app = web.Application()
        self._setup_routes()
    
    def _setup_routes(self):
        """Setup API routes"""
        self.app.router.add_get("/", self.handle_root)
        self.app.router.add_get("/health", self.handle_health)
        self.app.router.add_get("/status", self.handle_status)
        self.app.router.add_post("/v1/inference", self.handle_inference)
        self.app.router.add_post("/v1/chat/completions", self.handle_chat)  # OpenAI compatible
        self.app.router.add_get("/v1/models", self.handle_models)
    
    async def handle_root(self, request: web.Request) -> web.Response:
        """Root endpoint"""
        return web.json_response({
            "name": "FPGA.Network Inference Server",
            "version": "0.1.0",
            "provider": self.config.name,
            "fpga": self.config.fpga.device_type,
            "endpoints": {
                "health": "/health",
                "status": "/status",
                "inference": "/v1/inference",
                "chat": "/v1/chat/completions",
                "models": "/v1/models"
            }
        })
    
    async def handle_health(self, request: web.Request) -> web.Response:
        """Health check endpoint"""
        return web.json_response({
            "status": "healthy",
            "fpga": "connected" if self.engine.fpga else "disconnected"
        })
    
    async def handle_status(self, request: web.Request) -> web.Response:
        """Status endpoint with statistics"""
        stats = self.engine.get_stats()
        return web.json_response({
            "provider": self.config.name,
            "fpga_type": self.config.fpga.device_type,
            "wallet": self.config.wallet.address[:20] + "..." if self.config.wallet.address else None,
            "models": self.config.inference.supported_models,
            "price_per_1k_tokens": self.config.inference.price_per_1k_tokens,
            "stats": stats
        })
    
    async def handle_inference(self, request: web.Request) -> web.Response:
        """Main inference endpoint"""
        try:
            data = await request.json()
        except json.JSONDecodeError:
            return web.json_response({"error": "Invalid JSON"}, status=400)
        
        # Validate request
        if "prompt" not in data:
            return web.json_response({"error": "Missing 'prompt' field"}, status=400)
        
        # Create inference request
        inference_request = InferenceRequest(
            id=str(uuid.uuid4()),
            model=data.get("model", "bitnet-3b"),
            prompt=data["prompt"],
            max_tokens=data.get("max_tokens", 256),
            temperature=data.get("temperature", 0.7),
            nonce=data.get("nonce", str(uuid.uuid4())),
            requestor_id=data.get("requestor_id", request.remote),
        )
        
        # Process inference
        result = await self.engine.process(inference_request)
        
        return web.json_response({
            "id": result.request_id,
            "model": inference_request.model,
            "output": result.output,
            "usage": {
                "prompt_tokens": len(inference_request.prompt.split()),
                "completion_tokens": result.tokens_generated,
                "total_tokens": len(inference_request.prompt.split()) + result.tokens_generated
            },
            "latency_ms": result.latency_ms,
            "proof": result.proof,
            "provider": self.config.name
        })
    
    async def handle_chat(self, request: web.Request) -> web.Response:
        """OpenAI-compatible chat completions endpoint"""
        try:
            data = await request.json()
        except json.JSONDecodeError:
            return web.json_response({"error": "Invalid JSON"}, status=400)
        
        # Extract messages
        messages = data.get("messages", [])
        if not messages:
            return web.json_response({"error": "Missing 'messages' field"}, status=400)
        
        # Convert messages to prompt
        prompt = "\n".join([
            f"{msg.get('role', 'user')}: {msg.get('content', '')}"
            for msg in messages
        ])
        
        # Create inference request
        inference_request = InferenceRequest(
            id=str(uuid.uuid4()),
            model=data.get("model", "bitnet-3b"),
            prompt=prompt,
            max_tokens=data.get("max_tokens", 256),
            temperature=data.get("temperature", 0.7),
            nonce=str(uuid.uuid4()),
            requestor_id=request.remote,
        )
        
        # Process inference
        result = await self.engine.process(inference_request)
        
        # Return OpenAI-compatible response
        return web.json_response({
            "id": f"chatcmpl-{result.request_id}",
            "object": "chat.completion",
            "created": int(asyncio.get_event_loop().time()),
            "model": inference_request.model,
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": result.output
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": len(prompt.split()),
                "completion_tokens": result.tokens_generated,
                "total_tokens": len(prompt.split()) + result.tokens_generated
            },
            "fpga_network": {
                "provider": self.config.name,
                "latency_ms": result.latency_ms,
                "proof": result.proof
            }
        })
    
    async def handle_models(self, request: web.Request) -> web.Response:
        """List available models"""
        models = []
        for model_id in self.config.inference.supported_models:
            models.append({
                "id": model_id,
                "object": "model",
                "owned_by": "fpga-network",
                "permission": []
            })
        
        return web.json_response({
            "object": "list",
            "data": models
        })
    
    async def start(self, host: str = "0.0.0.0", port: int = 8080):
        """Start the server"""
        runner = web.AppRunner(self.app)
        await runner.setup()
        site = web.TCPSite(runner, host, port)
        await site.start()
        print(f"   REST API listening on http://{host}:{port}")
        return runner


async def run_server(config: AgentConfig):
    """Run the inference server"""
    # Initialize engine
    engine = InferenceEngine(config)
    await engine.initialize()
    
    # Create and start server
    server = InferenceServer(config, engine)
    runner = await server.start()
    
    # Keep running
    try:
        while True:
            await asyncio.sleep(3600)
    except asyncio.CancelledError:
        await runner.cleanup()


if __name__ == "__main__":
    from agent.config import AgentConfig
    
    config = AgentConfig.load()
    asyncio.run(run_server(config))
