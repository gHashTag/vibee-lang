"""
Lion Optimizer
==============

Memory-efficient optimizer that uses sign of momentum.
Uses 8 bytes/param instead of 12 bytes/param (AdamW).

Reference: Chen et al. (2023) - Symbolic Discovery of Optimization Algorithms

Usage:
    optimizer = Lion(model.parameters(), lr=1e-4, weight_decay=0.1)
    
Note: Use 3-10x smaller LR and 3-10x larger weight_decay compared to AdamW.
"""

import torch
from torch.optim import Optimizer
from typing import Iterable, Callable, Optional


class Lion(Optimizer):
    """
    Lion optimizer - Evolved Sign Momentum.
    
    Args:
        params: Model parameters
        lr: Learning rate (use 3-10x smaller than AdamW)
        betas: Coefficients for computing running average (default: (0.9, 0.99))
        weight_decay: Weight decay coefficient (use 3-10x larger than AdamW)
    
    Memory: 8 bytes/param (vs 12 for AdamW)
    """
    
    def __init__(
        self,
        params: Iterable[torch.nn.Parameter],
        lr: float = 1e-4,
        betas: tuple = (0.9, 0.99),
        weight_decay: float = 0.1,
    ):
        if lr < 0.0:
            raise ValueError(f"Invalid learning rate: {lr}")
        if not 0.0 <= betas[0] < 1.0:
            raise ValueError(f"Invalid beta1: {betas[0]}")
        if not 0.0 <= betas[1] < 1.0:
            raise ValueError(f"Invalid beta2: {betas[1]}")
        
        defaults = dict(lr=lr, betas=betas, weight_decay=weight_decay)
        super().__init__(params, defaults)
    
    @torch.no_grad()
    def step(self, closure: Optional[Callable] = None):
        """Perform a single optimization step."""
        loss = None
        if closure is not None:
            with torch.enable_grad():
                loss = closure()
        
        for group in self.param_groups:
            for p in group["params"]:
                if p.grad is None:
                    continue
                
                grad = p.grad
                if grad.is_sparse:
                    raise RuntimeError("Lion does not support sparse gradients")
                
                state = self.state[p]
                
                # Initialize state
                if len(state) == 0:
                    state["exp_avg"] = torch.zeros_like(p)
                
                exp_avg = state["exp_avg"]
                beta1, beta2 = group["betas"]
                
                # Weight decay (decoupled)
                if group["weight_decay"] != 0:
                    p.mul_(1 - group["lr"] * group["weight_decay"])
                
                # Lion update: sign of interpolation between momentum and gradient
                update = exp_avg * beta1 + grad * (1 - beta1)
                p.add_(torch.sign(update), alpha=-group["lr"])
                
                # Update momentum
                exp_avg.mul_(beta2).add_(grad, alpha=1 - beta2)
        
        return loss


def lion_hyperparams_from_adamw(adamw_lr: float, adamw_wd: float) -> dict:
    """
    Convert AdamW hyperparameters to Lion equivalents.
    
    Args:
        adamw_lr: AdamW learning rate
        adamw_wd: AdamW weight decay
        
    Returns:
        Dictionary with Lion hyperparameters
    """
    return {
        "lr": adamw_lr / 5,  # 3-10x smaller
        "weight_decay": adamw_wd * 5,  # 3-10x larger
        "betas": (0.9, 0.99),
    }
