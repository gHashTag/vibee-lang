"""
FPGA.Network Agent Configuration
"""

import os
import yaml
from dataclasses import dataclass, field
from typing import Optional, List
from pathlib import Path

# Default paths
DEFAULT_CONFIG_PATH = Path.home() / ".fpga-network" / "config.yaml"
DEFAULT_BITSTREAM_DIR = Path.home() / ".fpga-network" / "bitstreams"
DEFAULT_LOG_DIR = Path.home() / ".fpga-network" / "logs"

@dataclass
class FPGAConfig:
    """FPGA hardware configuration"""
    device_type: str = "alveo_u55c"  # alveo_u50, alveo_u55c, alveo_u280, arty_a7
    device_id: int = 0
    bitstream_path: Optional[str] = None
    clock_freq_mhz: int = 300

@dataclass
class NetworkConfig:
    """Network configuration"""
    coordinator_url: str = "https://api.fpga.network"
    heartbeat_interval: int = 30  # seconds
    max_concurrent_requests: int = 10

@dataclass
class WalletConfig:
    """Solana wallet configuration"""
    address: str = ""
    keypair_path: Optional[str] = None
    min_stake: int = 10000  # Minimum $FPGA to stake

@dataclass
class InferenceConfig:
    """Inference settings"""
    supported_models: List[str] = field(default_factory=lambda: [
        "bitnet-1b",
        "bitnet-3b", 
        "bitnet-7b"
    ])
    max_tokens: int = 4096
    timeout_seconds: int = 60
    price_per_1k_tokens: float = 0.0001  # in $FPGA

@dataclass
class AgentConfig:
    """Main agent configuration"""
    fpga: FPGAConfig = field(default_factory=FPGAConfig)
    network: NetworkConfig = field(default_factory=NetworkConfig)
    wallet: WalletConfig = field(default_factory=WalletConfig)
    inference: InferenceConfig = field(default_factory=InferenceConfig)
    
    # Agent metadata
    name: str = "fpga-provider-1"
    region: str = "auto"  # auto-detect or specify
    log_level: str = "INFO"
    
    @classmethod
    def load(cls, path: Path = DEFAULT_CONFIG_PATH) -> "AgentConfig":
        """Load configuration from YAML file"""
        if not path.exists():
            return cls()
        
        with open(path) as f:
            data = yaml.safe_load(f)
        
        return cls(
            fpga=FPGAConfig(**data.get("fpga", {})),
            network=NetworkConfig(**data.get("network", {})),
            wallet=WalletConfig(**data.get("wallet", {})),
            inference=InferenceConfig(**data.get("inference", {})),
            name=data.get("name", "fpga-provider-1"),
            region=data.get("region", "auto"),
            log_level=data.get("log_level", "INFO")
        )
    
    def save(self, path: Path = DEFAULT_CONFIG_PATH):
        """Save configuration to YAML file"""
        path.parent.mkdir(parents=True, exist_ok=True)
        
        data = {
            "name": self.name,
            "region": self.region,
            "log_level": self.log_level,
            "fpga": {
                "device_type": self.fpga.device_type,
                "device_id": self.fpga.device_id,
                "bitstream_path": self.fpga.bitstream_path,
                "clock_freq_mhz": self.fpga.clock_freq_mhz
            },
            "network": {
                "coordinator_url": self.network.coordinator_url,
                "heartbeat_interval": self.network.heartbeat_interval,
                "max_concurrent_requests": self.network.max_concurrent_requests
            },
            "wallet": {
                "address": self.wallet.address,
                "keypair_path": self.wallet.keypair_path,
                "min_stake": self.wallet.min_stake
            },
            "inference": {
                "supported_models": self.inference.supported_models,
                "max_tokens": self.inference.max_tokens,
                "timeout_seconds": self.inference.timeout_seconds,
                "price_per_1k_tokens": self.inference.price_per_1k_tokens
            }
        }
        
        with open(path, "w") as f:
            yaml.dump(data, f, default_flow_style=False)


def generate_default_config():
    """Generate default configuration file"""
    config = AgentConfig()
    config.save()
    print(f"Default configuration saved to {DEFAULT_CONFIG_PATH}")
    return config


# Environment variable overrides
def get_config_from_env() -> AgentConfig:
    """Load configuration with environment variable overrides"""
    config = AgentConfig.load()
    
    # Override with environment variables
    if os.getenv("FPGA_DEVICE_TYPE"):
        config.fpga.device_type = os.getenv("FPGA_DEVICE_TYPE")
    if os.getenv("FPGA_WALLET_ADDRESS"):
        config.wallet.address = os.getenv("FPGA_WALLET_ADDRESS")
    if os.getenv("FPGA_COORDINATOR_URL"):
        config.network.coordinator_url = os.getenv("FPGA_COORDINATOR_URL")
    if os.getenv("FPGA_PRICE_PER_1K"):
        config.inference.price_per_1k_tokens = float(os.getenv("FPGA_PRICE_PER_1K"))
    
    return config
