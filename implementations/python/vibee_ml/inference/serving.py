"""Model Serving Utilities."""

from dataclasses import dataclass
from typing import Optional
import subprocess
import sys


@dataclass
class ServingConfig:
    """Configuration for model serving."""
    model_path: str = ""
    host: str = "0.0.0.0"
    port: int = 8000
    tensor_parallel_size: int = 1
    gpu_memory_utilization: float = 0.9
    max_num_seqs: int = 256
    backend: str = "vllm"  # "vllm", "tgi", "triton"


def serve_model(config: ServingConfig) -> subprocess.Popen:
    """
    Start model serving.
    
    Args:
        config: Serving configuration
        
    Returns:
        Subprocess handle
    """
    if config.backend == "vllm":
        return _serve_vllm(config)
    elif config.backend == "tgi":
        return _serve_tgi(config)
    else:
        raise ValueError(f"Unknown backend: {config.backend}")


def _serve_vllm(config: ServingConfig) -> subprocess.Popen:
    """Start vLLM server."""
    cmd = [
        sys.executable, "-m", "vllm.entrypoints.openai.api_server",
        "--model", config.model_path,
        "--host", config.host,
        "--port", str(config.port),
        "--tensor-parallel-size", str(config.tensor_parallel_size),
        "--gpu-memory-utilization", str(config.gpu_memory_utilization),
        "--max-num-seqs", str(config.max_num_seqs),
    ]
    return subprocess.Popen(cmd)


def _serve_tgi(config: ServingConfig) -> subprocess.Popen:
    """Start TGI server via Docker."""
    cmd = [
        "docker", "run", "--gpus", "all",
        "-p", f"{config.port}:80",
        "ghcr.io/huggingface/text-generation-inference:latest",
        "--model-id", config.model_path,
        "--num-shard", str(config.tensor_parallel_size),
    ]
    return subprocess.Popen(cmd)


def get_vllm_command(config: ServingConfig) -> str:
    """Get vLLM command string."""
    return f"""python -m vllm.entrypoints.openai.api_server \\
    --model {config.model_path} \\
    --host {config.host} \\
    --port {config.port} \\
    --tensor-parallel-size {config.tensor_parallel_size} \\
    --gpu-memory-utilization {config.gpu_memory_utilization}"""
