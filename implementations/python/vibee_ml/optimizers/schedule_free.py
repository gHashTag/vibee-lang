"""
Schedule-Free AdamW
===================

Optimizer that doesn't require learning rate scheduling.

Reference: Defazio et al. (2024) - The Road Less Scheduled
"""

import torch
from torch.optim import Optimizer
from typing import Iterable, Callable, Optional


class ScheduleFreeAdamW(Optimizer):
    """
    Schedule-Free AdamW - No LR schedule needed.
    
    Args:
        params: Model parameters
        lr: Learning rate (can use higher than AdamW)
        betas: Coefficients (default: (0.9, 0.999))
        weight_decay: Weight decay
        warmup_steps: Warmup steps (optional)
    """
    
    def __init__(
        self,
        params: Iterable[torch.nn.Parameter],
        lr: float = 1e-3,
        betas: tuple = (0.9, 0.999),
        eps: float = 1e-8,
        weight_decay: float = 0.01,
        warmup_steps: int = 0,
    ):
        defaults = dict(lr=lr, betas=betas, eps=eps, weight_decay=weight_decay, warmup_steps=warmup_steps)
        super().__init__(params, defaults)
        self.step_count = 0
        self._is_train_mode = True
    
    def train(self):
        """Set to training mode."""
        self._is_train_mode = True
        for group in self.param_groups:
            for p in group["params"]:
                state = self.state[p]
                if "z" in state:
                    p.data.copy_(state["z"])
    
    def eval(self):
        """Set to evaluation mode."""
        self._is_train_mode = False
        for group in self.param_groups:
            beta1, _ = group["betas"]
            for p in group["params"]:
                state = self.state[p]
                if "z" in state:
                    # Use averaged weights for eval
                    p.data.copy_(state["z"].lerp(p.data, 1 - beta1))
    
    @torch.no_grad()
    def step(self, closure: Optional[Callable] = None):
        """Perform optimization step."""
        loss = None
        if closure is not None:
            with torch.enable_grad():
                loss = closure()
        
        self.step_count += 1
        
        for group in self.param_groups:
            beta1, beta2 = group["betas"]
            
            # Warmup
            lr = group["lr"]
            if group["warmup_steps"] > 0 and self.step_count < group["warmup_steps"]:
                lr = lr * self.step_count / group["warmup_steps"]
            
            for p in group["params"]:
                if p.grad is None:
                    continue
                
                grad = p.grad
                state = self.state[p]
                
                if len(state) == 0:
                    state["exp_avg"] = torch.zeros_like(p)
                    state["exp_avg_sq"] = torch.zeros_like(p)
                    state["z"] = p.data.clone()
                
                exp_avg, exp_avg_sq = state["exp_avg"], state["exp_avg_sq"]
                z = state["z"]
                
                # Update moments
                exp_avg.mul_(beta1).add_(grad, alpha=1 - beta1)
                exp_avg_sq.mul_(beta2).addcmul_(grad, grad, value=1 - beta2)
                
                # Bias correction
                bias_correction1 = 1 - beta1 ** self.step_count
                bias_correction2 = 1 - beta2 ** self.step_count
                
                # Update z
                denom = (exp_avg_sq.sqrt() / (bias_correction2 ** 0.5)).add_(group["eps"])
                step_size = lr / bias_correction1
                
                if group["weight_decay"] != 0:
                    z.add_(z, alpha=-lr * group["weight_decay"])
                
                z.addcdiv_(exp_avg, denom, value=-step_size)
                
                # Update p (interpolation)
                p.data.lerp_(z, 1 - beta1)
        
        return loss
