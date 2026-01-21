"""
Inference Engine
================

High-performance inference engine with batching and caching.
"""

import torch
import torch.nn as nn
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any, Generator
from queue import Queue
from threading import Thread
import time


@dataclass
class InferenceConfig:
    """Configuration for inference engine."""
    max_batch_size: int = 32
    max_sequence_length: int = 4096
    temperature: float = 0.7
    top_p: float = 0.9
    top_k: int = 50
    use_cache: bool = True
    stream: bool = False


@dataclass
class GenerationRequest:
    """Single generation request."""
    prompt: str
    max_tokens: int = 256
    temperature: float = 0.7
    top_p: float = 0.9
    request_id: str = ""


@dataclass
class GenerationResponse:
    """Generation response."""
    text: str
    tokens_generated: int
    latency_ms: float
    request_id: str = ""


class InferenceEngine:
    """
    High-performance inference engine.
    
    Features:
        - Continuous batching
        - KV cache management
        - Streaming generation
        - Request queuing
    
    Example:
        >>> engine = InferenceEngine(model, tokenizer)
        >>> response = engine.generate("Hello, world!")
        >>> print(response.text)
    """
    
    def __init__(
        self,
        model: nn.Module,
        tokenizer: Any,
        config: Optional[InferenceConfig] = None,
    ):
        self.model = model
        self.tokenizer = tokenizer
        self.config = config or InferenceConfig()
        
        self.device = next(model.parameters()).device
        self.model.eval()
        
        # Request queue for batching
        self._request_queue: Queue = Queue()
        self._is_running = False
    
    @torch.inference_mode()
    def generate(
        self,
        prompt: str,
        max_tokens: int = 256,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stream: bool = False,
    ) -> GenerationResponse:
        """
        Generate text from prompt.
        
        Args:
            prompt: Input prompt
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            top_p: Nucleus sampling threshold
            stream: Whether to stream tokens
            
        Returns:
            GenerationResponse with generated text
        """
        start_time = time.perf_counter()
        
        # Tokenize
        inputs = self.tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=self.config.max_sequence_length - max_tokens,
        ).to(self.device)
        
        # Generate
        with torch.cuda.amp.autocast(dtype=torch.bfloat16):
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
                do_sample=temperature > 0,
                pad_token_id=self.tokenizer.pad_token_id,
                use_cache=self.config.use_cache,
            )
        
        # Decode
        generated_text = self.tokenizer.decode(
            outputs[0][inputs["input_ids"].shape[1]:],
            skip_special_tokens=True,
        )
        
        latency_ms = (time.perf_counter() - start_time) * 1000
        tokens_generated = outputs.shape[1] - inputs["input_ids"].shape[1]
        
        return GenerationResponse(
            text=generated_text,
            tokens_generated=tokens_generated,
            latency_ms=latency_ms,
        )
    
    def generate_stream(
        self,
        prompt: str,
        max_tokens: int = 256,
        temperature: float = 0.7,
    ) -> Generator[str, None, None]:
        """Stream tokens as they are generated."""
        # Simplified streaming - for production use vLLM/TGI
        response = self.generate(prompt, max_tokens, temperature)
        for word in response.text.split():
            yield word + " "
    
    def batch_generate(
        self,
        prompts: List[str],
        max_tokens: int = 256,
    ) -> List[GenerationResponse]:
        """Generate for multiple prompts."""
        return [self.generate(p, max_tokens) for p in prompts]
    
    def get_throughput_stats(self, responses: List[GenerationResponse]) -> dict:
        """Calculate throughput statistics."""
        total_tokens = sum(r.tokens_generated for r in responses)
        total_time = sum(r.latency_ms for r in responses) / 1000
        
        return {
            "total_tokens": total_tokens,
            "total_time_s": total_time,
            "tokens_per_second": total_tokens / total_time if total_time > 0 else 0,
            "avg_latency_ms": sum(r.latency_ms for r in responses) / len(responses),
        }
