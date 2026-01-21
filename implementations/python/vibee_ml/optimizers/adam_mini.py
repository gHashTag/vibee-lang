"""
Adam-mini Optimizer
===================

Memory-efficient Adam that shares optimizer states.
Uses 6 bytes/param instead of 12 bytes/param.

Reference: Zhang et al. (2024) - Adam-mini: Use Fewer Learning Rates To Gain More
"""

import torch
from torch.optim import Optimizer
from typing import Iterable, Callable, Optional


class AdamMini(Optimizer):
    """
    Adam-mini - Memory-efficient Adam variant.
    
    Shares optimizer states across parameters in the same layer.
    
    Args:
        params: Model parameters
        lr: Learning rate
        betas: Coefficients
        eps: Epsilon for numerical stability
        weight_decay: Weight decay
    """
    
    def __init__(
        self,
        params: Iterable[torch.nn.Parameter],
        lr: float = 1e-4,
        betas: tuple = (0.9, 0.999),
        eps: float = 1e-8,
        weight_decay: float = 0.01,
    ):
        defaults = dict(lr=lr, betas=betas, eps=eps, weight_decay=weight_decay)
        super().__init__(params, defaults)
    
    @torch.no_grad()
    def step(self, closure: Optional[Callable] = None):
        """Perform optimization step."""
        loss = None
        if closure is not None:
            with torch.enable_grad():
                loss = closure()
        
        for group in self.param_groups:
            beta1, beta2 = group["betas"]
            
            for p in group["params"]:
                if p.grad is None:
                    continue
                
                grad = p.grad
                state = self.state[p]
                
                if len(state) == 0:
                    state["step"] = 0
                    state["exp_avg"] = torch.zeros_like(p)
                    # Share exp_avg_sq across dimensions (memory saving)
                    state["exp_avg_sq"] = torch.zeros(1, device=p.device, dtype=p.dtype)
                
                state["step"] += 1
                exp_avg = state["exp_avg"]
                exp_avg_sq = state["exp_avg_sq"]
                
                # Update first moment
                exp_avg.mul_(beta1).add_(grad, alpha=1 - beta1)
                
                # Update second moment (scalar, shared)
                grad_sq_mean = (grad * grad).mean()
                exp_avg_sq.mul_(beta2).add_(grad_sq_mean, alpha=1 - beta2)
                
                # Bias correction
                bias_correction1 = 1 - beta1 ** state["step"]
                bias_correction2 = 1 - beta2 ** state["step"]
                
                # Weight decay
                if group["weight_decay"] != 0:
                    p.mul_(1 - group["lr"] * group["weight_decay"])
                
                # Update
                denom = (exp_avg_sq.sqrt() / (bias_correction2 ** 0.5)).add_(group["eps"])
                step_size = group["lr"] / bias_correction1
                p.addcdiv_(exp_avg, denom.expand_as(exp_avg), value=-step_size)
        
        return loss
