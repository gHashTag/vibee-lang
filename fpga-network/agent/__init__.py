"""
FPGA.Network Agent

Decentralized BitNet LLM Inference on FPGA
"""

__version__ = "0.1.0"
__author__ = "FPGA.Network Team"

from agent.config import AgentConfig
from agent.inference import InferenceEngine, InferenceRequest, InferenceResult
from agent.network import NetworkClient
from agent.proof import ProofGenerator, ProofVerifier

__all__ = [
    "AgentConfig",
    "InferenceEngine",
    "InferenceRequest", 
    "InferenceResult",
    "NetworkClient",
    "ProofGenerator",
    "ProofVerifier",
]
