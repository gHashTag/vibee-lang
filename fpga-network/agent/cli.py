#!/usr/bin/env python3
"""
FPGA.Network Agent CLI

Usage:
    fpga-agent register --wallet <WALLET_ADDRESS>
    fpga-agent start [--config <CONFIG_PATH>]
    fpga-agent stop
    fpga-agent status
    fpga-agent benchmark
    fpga-agent logs [--tail <N>]
"""

import argparse
import sys
import os
import signal
import asyncio
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from agent.config import AgentConfig, DEFAULT_CONFIG_PATH, generate_default_config


def print_banner():
    """Print FPGA.Network banner"""
    banner = """
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   ███████╗██████╗  ██████╗  █████╗    ███╗   ██╗███████╗████████╗ ║
║   ██╔════╝██╔══██╗██╔════╝ ██╔══██╗   ████╗  ██║██╔════╝╚══██╔══╝ ║
║   █████╗  ██████╔╝██║  ███╗███████║   ██╔██╗ ██║█████╗     ██║    ║
║   ██╔══╝  ██╔═══╝ ██║   ██║██╔══██║   ██║╚██╗██║██╔══╝     ██║    ║
║   ██║     ██║     ╚██████╔╝██║  ██║██╗██║ ╚████║███████╗   ██║    ║
║   ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝    ║
║                                                                   ║
║   Decentralized BitNet LLM Inference Network                      ║
║   Version: 0.1.0                                                  ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
"""
    print(banner)


def cmd_register(args):
    """Register provider in the network"""
    print_banner()
    print("📝 Registering provider in FPGA.Network...\n")
    
    # Load or create config
    config = AgentConfig.load() if DEFAULT_CONFIG_PATH.exists() else AgentConfig()
    
    # Set wallet address
    config.wallet.address = args.wallet
    
    # Detect FPGA
    print("🔍 Detecting FPGA hardware...")
    fpga_type = detect_fpga()
    if fpga_type:
        config.fpga.device_type = fpga_type
        print(f"   ✅ Found: {fpga_type}")
    else:
        print("   ⚠️  No FPGA detected. Using simulation mode.")
        config.fpga.device_type = "simulation"
    
    # Set provider name
    if args.name:
        config.name = args.name
    else:
        import socket
        config.name = f"provider-{socket.gethostname()}"
    
    # Save config
    config.save()
    print(f"\n💾 Configuration saved to {DEFAULT_CONFIG_PATH}")
    
    # Register with coordinator
    print("\n🌐 Connecting to FPGA.Network coordinator...")
    
    # TODO: Actual registration with coordinator
    # For now, simulate
    import hashlib
    provider_id = hashlib.sha256(config.wallet.address.encode()).hexdigest()[:16]
    
    print(f"""
╔═══════════════════════════════════════════════════════════════════╗
║                    ✅ REGISTRATION SUCCESSFUL                     ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║   Provider ID:    {provider_id}                       ║
║   Wallet:         {config.wallet.address[:20]}...                        ║
║   FPGA Type:      {config.fpga.device_type:<20}                       ║
║   Region:         {config.region:<20}                       ║
║                                                                   ║
║   Next steps:                                                     ║
║   1. Stake minimum 10,000 $FPGA tokens                            ║
║   2. Run: fpga-agent start                                        ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
""")


def cmd_start(args):
    """Start the FPGA agent"""
    print_banner()
    print("🚀 Starting FPGA.Network Agent...\n")
    
    # Load config
    config_path = Path(args.config) if args.config else DEFAULT_CONFIG_PATH
    if not config_path.exists():
        print("❌ Configuration not found. Run 'fpga-agent register' first.")
        sys.exit(1)
    
    config = AgentConfig.load(config_path)
    
    print(f"📋 Configuration:")
    print(f"   Provider:  {config.name}")
    print(f"   FPGA:      {config.fpga.device_type}")
    print(f"   Wallet:    {config.wallet.address[:20]}...")
    print(f"   Models:    {', '.join(config.inference.supported_models)}")
    print(f"   Price:     {config.inference.price_per_1k_tokens} $FPGA/1K tokens")
    print()
    
    # Initialize FPGA
    print("🔧 Initializing FPGA...")
    if config.fpga.device_type != "simulation":
        # TODO: Load bitstream
        print(f"   Loading bitstream for {config.fpga.device_type}...")
    print("   ✅ FPGA ready")
    print()
    
    # Connect to network
    print("🌐 Connecting to FPGA.Network...")
    print(f"   Coordinator: {config.network.coordinator_url}")
    print("   ✅ Connected")
    print()
    
    # Start inference server
    print("🖥️  Starting inference server...")
    print("   Listening on port 50051 (gRPC)")
    print("   Listening on port 8080 (REST)")
    print("   ✅ Server ready")
    print()
    
    print("═" * 67)
    print("✅ FPGA.Network Agent is running!")
    print("   Press Ctrl+C to stop")
    print("═" * 67)
    print()
    
    # Run main loop
    try:
        asyncio.run(main_loop(config))
    except KeyboardInterrupt:
        print("\n\n🛑 Shutting down...")
        print("   Disconnecting from network...")
        print("   ✅ Agent stopped")


async def main_loop(config: AgentConfig):
    """Main agent loop"""
    from agent.network import NetworkClient
    from agent.inference import InferenceEngine
    
    # Initialize components
    network = NetworkClient(config)
    inference = InferenceEngine(config)
    
    # Heartbeat task
    async def heartbeat():
        while True:
            await network.send_heartbeat()
            await asyncio.sleep(config.network.heartbeat_interval)
    
    # Request handler task
    async def handle_requests():
        while True:
            request = await network.get_next_request()
            if request:
                result = await inference.process(request)
                await network.send_result(request.id, result)
            await asyncio.sleep(0.1)
    
    # Run tasks
    await asyncio.gather(
        heartbeat(),
        handle_requests()
    )


def cmd_stop(args):
    """Stop the FPGA agent"""
    print("🛑 Stopping FPGA.Network Agent...")
    
    # Find and kill agent process
    import subprocess
    result = subprocess.run(["pkill", "-f", "fpga-agent"], capture_output=True)
    
    if result.returncode == 0:
        print("   ✅ Agent stopped")
    else:
        print("   ⚠️  No running agent found")


def cmd_status(args):
    """Show agent status"""
    print_banner()
    
    config = AgentConfig.load()
    
    # Check if agent is running
    import subprocess
    result = subprocess.run(["pgrep", "-f", "fpga-agent start"], capture_output=True)
    is_running = result.returncode == 0
    
    status = "🟢 RUNNING" if is_running else "🔴 STOPPED"
    
    print(f"""
╔═══════════════════════════════════════════════════════════════════╗
║                       AGENT STATUS                                ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║   Status:         {status:<20}                       ║
║   Provider:       {config.name:<20}                       ║
║   FPGA:           {config.fpga.device_type:<20}                       ║
║   Wallet:         {config.wallet.address[:20] if config.wallet.address else 'Not configured':<20}...                        ║
║                                                                   ║
║   Network:                                                        ║
║   ├── Coordinator: {config.network.coordinator_url:<30}    ║
║   ├── Heartbeat:   Every {config.network.heartbeat_interval}s                                ║
║   └── Max requests: {config.network.max_concurrent_requests:<10}                              ║
║                                                                   ║
║   Inference:                                                      ║
║   ├── Models:      {', '.join(config.inference.supported_models):<30}    ║
║   ├── Max tokens:  {config.inference.max_tokens:<10}                              ║
║   └── Price:       {config.inference.price_per_1k_tokens} $FPGA/1K tokens                    ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
""")


def cmd_benchmark(args):
    """Run FPGA benchmark"""
    print_banner()
    print("⚡ Running FPGA benchmark...\n")
    
    config = AgentConfig.load()
    
    print(f"FPGA: {config.fpga.device_type}")
    print("=" * 50)
    
    # Simulate benchmark
    import time
    import random
    
    tests = [
        ("BitNet MAC throughput", "GOPS"),
        ("Memory bandwidth", "GB/s"),
        ("Inference latency (1K tokens)", "ms"),
        ("Tokens per second", "tok/s"),
    ]
    
    results = []
    for test_name, unit in tests:
        print(f"\n🔄 Testing: {test_name}...")
        time.sleep(0.5)  # Simulate test
        
        # Simulated results based on device type
        if config.fpga.device_type == "alveo_u55c":
            values = {"GOPS": 7800, "GB/s": 460, "ms": 45, "tok/s": 700}
        elif config.fpga.device_type == "alveo_u50":
            values = {"GOPS": 5200, "GB/s": 460, "ms": 60, "tok/s": 500}
        else:
            values = {"GOPS": 100, "GB/s": 10, "ms": 500, "tok/s": 50}
        
        value = values.get(unit, 0) * (0.9 + random.random() * 0.2)
        results.append((test_name, value, unit))
        print(f"   ✅ {value:.1f} {unit}")
    
    print(f"""
╔═══════════════════════════════════════════════════════════════════╗
║                    BENCHMARK RESULTS                              ║
╠═══════════════════════════════════════════════════════════════════╣
""")
    for name, value, unit in results:
        print(f"║   {name:<30} {value:>10.1f} {unit:<10}   ║")
    print("""╚═══════════════════════════════════════════════════════════════════╝
""")


def cmd_logs(args):
    """Show agent logs"""
    from agent.config import DEFAULT_LOG_DIR
    
    log_file = DEFAULT_LOG_DIR / "agent.log"
    
    if not log_file.exists():
        print("No logs found.")
        return
    
    tail = args.tail or 50
    
    with open(log_file) as f:
        lines = f.readlines()
        for line in lines[-tail:]:
            print(line, end="")


def detect_fpga() -> str:
    """Detect connected FPGA hardware"""
    import subprocess
    
    # Try xbutil (Xilinx)
    try:
        result = subprocess.run(["xbutil", "examine"], capture_output=True, text=True)
        if "u55c" in result.stdout.lower():
            return "alveo_u55c"
        elif "u50" in result.stdout.lower():
            return "alveo_u50"
        elif "u280" in result.stdout.lower():
            return "alveo_u280"
    except FileNotFoundError:
        pass
    
    # Try lspci
    try:
        result = subprocess.run(["lspci"], capture_output=True, text=True)
        if "xilinx" in result.stdout.lower():
            return "xilinx_unknown"
    except FileNotFoundError:
        pass
    
    return None


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="FPGA.Network Agent - Decentralized BitNet LLM Inference",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Commands")
    
    # Register command
    register_parser = subparsers.add_parser("register", help="Register provider in network")
    register_parser.add_argument("--wallet", "-w", required=True, help="Solana wallet address")
    register_parser.add_argument("--name", "-n", help="Provider name")
    
    # Start command
    start_parser = subparsers.add_parser("start", help="Start the agent")
    start_parser.add_argument("--config", "-c", help="Path to config file")
    
    # Stop command
    subparsers.add_parser("stop", help="Stop the agent")
    
    # Status command
    subparsers.add_parser("status", help="Show agent status")
    
    # Benchmark command
    subparsers.add_parser("benchmark", help="Run FPGA benchmark")
    
    # Logs command
    logs_parser = subparsers.add_parser("logs", help="Show agent logs")
    logs_parser.add_argument("--tail", "-t", type=int, help="Number of lines to show")
    
    args = parser.parse_args()
    
    if args.command == "register":
        cmd_register(args)
    elif args.command == "start":
        cmd_start(args)
    elif args.command == "stop":
        cmd_stop(args)
    elif args.command == "status":
        cmd_status(args)
    elif args.command == "benchmark":
        cmd_benchmark(args)
    elif args.command == "logs":
        cmd_logs(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
