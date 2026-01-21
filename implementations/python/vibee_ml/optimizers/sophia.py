"""
Sophia Optimizer
================

Second-order optimizer using Hessian diagonal approximation.
Claims 2x faster convergence than AdamW.

Reference: Liu et al. (2024) - Sophia: A Scalable Stochastic Second-order Optimizer
"""

import torch
from torch.optim import Optimizer
from typing import Iterable, Callable, Optional


class Sophia(Optimizer):
    """
    Sophia optimizer - Second-order with Hessian diagonal.
    
    Args:
        params: Model parameters
        lr: Learning rate
        betas: Coefficients (default: (0.965, 0.99))
        rho: Clipping threshold (default: 0.04)
        weight_decay: Weight decay coefficient
        hessian_update_interval: Steps between Hessian updates
    """
    
    def __init__(
        self,
        params: Iterable[torch.nn.Parameter],
        lr: float = 1e-4,
        betas: tuple = (0.965, 0.99),
        rho: float = 0.04,
        weight_decay: float = 0.1,
        hessian_update_interval: int = 10,
    ):
        defaults = dict(
            lr=lr, betas=betas, rho=rho,
            weight_decay=weight_decay,
            hessian_update_interval=hessian_update_interval
        )
        super().__init__(params, defaults)
        self.step_count = 0
    
    @torch.no_grad()
    def step(self, closure: Optional[Callable] = None):
        """Perform optimization step."""
        loss = None
        if closure is not None:
            with torch.enable_grad():
                loss = closure()
        
        self.step_count += 1
        
        for group in self.param_groups:
            for p in group["params"]:
                if p.grad is None:
                    continue
                
                grad = p.grad
                state = self.state[p]
                
                if len(state) == 0:
                    state["exp_avg"] = torch.zeros_like(p)
                    state["hessian"] = torch.ones_like(p)
                
                exp_avg = state["exp_avg"]
                hessian = state["hessian"]
                beta1, beta2 = group["betas"]
                
                # Update momentum
                exp_avg.mul_(beta1).add_(grad, alpha=1 - beta1)
                
                # Update Hessian estimate periodically
                if self.step_count % group["hessian_update_interval"] == 0:
                    hessian.mul_(beta2).add_(grad * grad, alpha=1 - beta2)
                
                # Weight decay
                if group["weight_decay"] != 0:
                    p.mul_(1 - group["lr"] * group["weight_decay"])
                
                # Sophia update with clipping
                update = exp_avg / (hessian.clamp(min=1e-8) + 1e-8)
                update.clamp_(-group["rho"], group["rho"])
                p.add_(update, alpha=-group["lr"])
        
        return loss
