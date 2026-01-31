"""
FPGA.Network Client

Handles communication with the FPGA.Network coordinator.
"""

import asyncio
import aiohttp
import hashlib
import json
import time
from dataclasses import dataclass, asdict
from typing import Optional, List
from enum import Enum

from agent.config import AgentConfig
from agent.inference import InferenceRequest


class ProviderStatus(Enum):
    OFFLINE = "offline"
    ONLINE = "online"
    BUSY = "busy"
    MAINTENANCE = "maintenance"


@dataclass
class ProviderInfo:
    """Provider information for network registration"""
    id: str
    name: str
    wallet_address: str
    fpga_type: str
    region: str
    supported_models: List[str]
    price_per_1k_tokens: float
    max_concurrent_requests: int
    status: ProviderStatus = ProviderStatus.OFFLINE
    
    # Performance metrics
    avg_latency_ms: float = 0.0
    total_requests: int = 0
    uptime_percent: float = 100.0
    reputation_score: float = 1.0


@dataclass
class Heartbeat:
    """Heartbeat message to coordinator"""
    provider_id: str
    timestamp: float
    status: str
    current_load: int  # Number of active requests
    stats: dict


class NetworkClient:
    """Client for FPGA.Network coordinator communication"""
    
    def __init__(self, config: AgentConfig):
        self.config = config
        self.provider_id = self._generate_provider_id()
        self.session: Optional[aiohttp.ClientSession] = None
        self.registered = False
        self.pending_requests: asyncio.Queue = asyncio.Queue()
        self.active_requests = 0
    
    def _generate_provider_id(self) -> str:
        """Generate unique provider ID from wallet address"""
        data = f"{self.config.wallet.address}:{self.config.name}"
        return hashlib.sha256(data.encode()).hexdigest()[:32]
    
    async def connect(self):
        """Connect to coordinator"""
        if self.session is None:
            self.session = aiohttp.ClientSession()
        
        # Register with coordinator
        await self.register()
        
        # Start WebSocket connection for real-time requests
        asyncio.create_task(self._websocket_listener())
    
    async def disconnect(self):
        """Disconnect from coordinator"""
        if self.session:
            # Notify coordinator
            await self._send_status(ProviderStatus.OFFLINE)
            await self.session.close()
            self.session = None
    
    async def register(self) -> bool:
        """Register provider with coordinator"""
        provider_info = ProviderInfo(
            id=self.provider_id,
            name=self.config.name,
            wallet_address=self.config.wallet.address,
            fpga_type=self.config.fpga.device_type,
            region=self.config.region,
            supported_models=self.config.inference.supported_models,
            price_per_1k_tokens=self.config.inference.price_per_1k_tokens,
            max_concurrent_requests=self.config.network.max_concurrent_requests,
            status=ProviderStatus.ONLINE
        )
        
        try:
            url = f"{self.config.network.coordinator_url}/v1/providers/register"
            async with self.session.post(url, json=asdict(provider_info)) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    self.registered = True
                    print(f"   ✅ Registered with coordinator (ID: {self.provider_id[:16]}...)")
                    return True
                else:
                    print(f"   ❌ Registration failed: {resp.status}")
                    return False
        except aiohttp.ClientError as e:
            # Coordinator not available - run in standalone mode
            print(f"   ⚠️  Coordinator unavailable, running in standalone mode")
            self.registered = True  # Allow local operation
            return True
    
    async def send_heartbeat(self):
        """Send heartbeat to coordinator"""
        if not self.registered:
            return
        
        heartbeat = Heartbeat(
            provider_id=self.provider_id,
            timestamp=time.time(),
            status=ProviderStatus.ONLINE.value if self.active_requests < self.config.network.max_concurrent_requests else ProviderStatus.BUSY.value,
            current_load=self.active_requests,
            stats={
                "uptime": time.time(),  # TODO: Track actual uptime
                "total_requests": 0,  # TODO: Track from engine
            }
        )
        
        try:
            url = f"{self.config.network.coordinator_url}/v1/providers/{self.provider_id}/heartbeat"
            async with self.session.post(url, json=asdict(heartbeat)) as resp:
                if resp.status != 200:
                    print(f"   ⚠️  Heartbeat failed: {resp.status}")
        except aiohttp.ClientError:
            pass  # Silently ignore heartbeat failures
    
    async def _send_status(self, status: ProviderStatus):
        """Send status update to coordinator"""
        try:
            url = f"{self.config.network.coordinator_url}/v1/providers/{self.provider_id}/status"
            async with self.session.post(url, json={"status": status.value}) as resp:
                pass
        except aiohttp.ClientError:
            pass
    
    async def _websocket_listener(self):
        """Listen for incoming requests via WebSocket"""
        ws_url = self.config.network.coordinator_url.replace("https://", "wss://").replace("http://", "ws://")
        ws_url = f"{ws_url}/v1/providers/{self.provider_id}/ws"
        
        while True:
            try:
                async with self.session.ws_connect(ws_url) as ws:
                    print(f"   ✅ WebSocket connected to coordinator")
                    async for msg in ws:
                        if msg.type == aiohttp.WSMsgType.TEXT:
                            data = json.loads(msg.data)
                            if data.get("type") == "inference_request":
                                request = InferenceRequest(**data["request"])
                                await self.pending_requests.put(request)
                        elif msg.type == aiohttp.WSMsgType.ERROR:
                            break
            except aiohttp.ClientError:
                # Reconnect after delay
                await asyncio.sleep(5)
            except Exception as e:
                print(f"   ⚠️  WebSocket error: {e}")
                await asyncio.sleep(5)
    
    async def get_next_request(self) -> Optional[InferenceRequest]:
        """Get next pending inference request"""
        try:
            request = await asyncio.wait_for(
                self.pending_requests.get(),
                timeout=1.0
            )
            self.active_requests += 1
            return request
        except asyncio.TimeoutError:
            return None
    
    async def send_result(self, request_id: str, result):
        """Send inference result back to coordinator"""
        self.active_requests = max(0, self.active_requests - 1)
        
        try:
            url = f"{self.config.network.coordinator_url}/v1/results/{request_id}"
            async with self.session.post(url, json={
                "request_id": request_id,
                "provider_id": self.provider_id,
                "output": result.output,
                "tokens": result.tokens_generated,
                "latency_ms": result.latency_ms,
                "proof": result.proof
            }) as resp:
                if resp.status != 200:
                    print(f"   ⚠️  Failed to send result: {resp.status}")
        except aiohttp.ClientError as e:
            print(f"   ⚠️  Failed to send result: {e}")
    
    async def claim_rewards(self) -> dict:
        """Claim accumulated $FPGA rewards"""
        try:
            url = f"{self.config.network.coordinator_url}/v1/providers/{self.provider_id}/claim"
            async with self.session.post(url, json={
                "wallet": self.config.wallet.address
            }) as resp:
                if resp.status == 200:
                    return await resp.json()
                else:
                    return {"error": f"Claim failed: {resp.status}"}
        except aiohttp.ClientError as e:
            return {"error": str(e)}
    
    async def get_earnings(self) -> dict:
        """Get current earnings information"""
        try:
            url = f"{self.config.network.coordinator_url}/v1/providers/{self.provider_id}/earnings"
            async with self.session.get(url) as resp:
                if resp.status == 200:
                    return await resp.json()
                else:
                    return {"error": f"Failed to get earnings: {resp.status}"}
        except aiohttp.ClientError as e:
            return {"error": str(e)}


class StandaloneMode:
    """Standalone mode when coordinator is unavailable"""
    
    def __init__(self, config: AgentConfig):
        self.config = config
        self.requests: asyncio.Queue = asyncio.Queue()
    
    async def add_request(self, request: InferenceRequest):
        """Add request to queue (for local testing)"""
        await self.requests.put(request)
    
    async def get_next_request(self) -> Optional[InferenceRequest]:
        """Get next request from queue"""
        try:
            return await asyncio.wait_for(self.requests.get(), timeout=1.0)
        except asyncio.TimeoutError:
            return None
