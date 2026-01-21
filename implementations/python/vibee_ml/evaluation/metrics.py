"""
Metrics Collection
==================

Training and evaluation metrics.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional
import math
import torch


@dataclass
class MetricSnapshot:
    """Single metric snapshot."""
    step: int
    value: float
    timestamp: float = 0.0


class MetricsCollector:
    """
    Collect and aggregate training metrics.
    
    Example:
        >>> collector = MetricsCollector()
        >>> collector.log("loss", 2.5, step=100)
        >>> collector.log("accuracy", 0.85, step=100)
        >>> summary = collector.get_summary()
    """
    
    def __init__(self):
        self.metrics: Dict[str, List[MetricSnapshot]] = {}
    
    def log(self, name: str, value: float, step: int, timestamp: float = 0.0):
        """Log a metric value."""
        if name not in self.metrics:
            self.metrics[name] = []
        
        self.metrics[name].append(MetricSnapshot(
            step=step,
            value=value,
            timestamp=timestamp,
        ))
    
    def get(self, name: str) -> List[MetricSnapshot]:
        """Get all values for a metric."""
        return self.metrics.get(name, [])
    
    def get_latest(self, name: str) -> Optional[float]:
        """Get latest value for a metric."""
        values = self.metrics.get(name, [])
        return values[-1].value if values else None
    
    def get_summary(self) -> Dict[str, Dict[str, float]]:
        """Get summary statistics for all metrics."""
        summary = {}
        
        for name, snapshots in self.metrics.items():
            values = [s.value for s in snapshots]
            summary[name] = {
                "min": min(values),
                "max": max(values),
                "mean": sum(values) / len(values),
                "latest": values[-1],
                "count": len(values),
            }
        
        return summary
    
    def get_moving_average(self, name: str, window: int = 10) -> List[float]:
        """Get moving average for a metric."""
        values = [s.value for s in self.metrics.get(name, [])]
        if len(values) < window:
            return values
        
        result = []
        for i in range(len(values) - window + 1):
            avg = sum(values[i:i + window]) / window
            result.append(avg)
        
        return result
    
    def reset(self):
        """Reset all metrics."""
        self.metrics.clear()


def compute_perplexity(
    model: torch.nn.Module,
    dataloader: Any,
    device: torch.device,
) -> float:
    """
    Compute perplexity on a dataset.
    
    Args:
        model: Language model
        dataloader: DataLoader with input_ids
        device: Compute device
        
    Returns:
        Perplexity score
    """
    model.eval()
    total_loss = 0.0
    total_tokens = 0
    
    with torch.no_grad():
        for batch in dataloader:
            input_ids = batch["input_ids"].to(device)
            labels = input_ids.clone()
            
            outputs = model(input_ids, labels=labels)
            loss = outputs.loss
            
            # Count non-padding tokens
            num_tokens = (labels != -100).sum().item()
            total_loss += loss.item() * num_tokens
            total_tokens += num_tokens
    
    avg_loss = total_loss / total_tokens if total_tokens > 0 else float('inf')
    perplexity = math.exp(avg_loss)
    
    return perplexity


def compute_accuracy(
    predictions: torch.Tensor,
    labels: torch.Tensor,
    ignore_index: int = -100,
) -> float:
    """Compute token-level accuracy."""
    mask = labels != ignore_index
    correct = (predictions == labels) & mask
    accuracy = correct.sum().item() / mask.sum().item()
    return accuracy
