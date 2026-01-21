"""
Safety Evaluator
================

Comprehensive safety evaluation for LLM outputs.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional
from .guardrails import Guardrails, GuardrailConfig, GuardrailResult
from .filters import ContentFilter, FilterConfig, FilterResult


@dataclass
class SafetyScore:
    """Overall safety score."""
    score: float  # 0.0 (unsafe) to 1.0 (safe)
    passed: bool
    guardrail_result: Optional[GuardrailResult] = None
    filter_result: Optional[FilterResult] = None
    details: Dict[str, Any] = field(default_factory=dict)


class SafetyEvaluator:
    """
    Comprehensive safety evaluation combining guardrails and content filtering.
    
    Example:
        >>> evaluator = SafetyEvaluator()
        >>> score = evaluator.evaluate("Hello, world!")
        >>> print(score.passed)  # True
    """
    
    def __init__(
        self,
        guardrail_config: Optional[GuardrailConfig] = None,
        filter_config: Optional[FilterConfig] = None,
    ):
        self.guardrails = Guardrails(guardrail_config)
        self.content_filter = ContentFilter(filter_config)
    
    def evaluate(self, text: str, is_input: bool = False) -> SafetyScore:
        """
        Evaluate text for safety.
        
        Args:
            text: Text to evaluate
            is_input: Whether this is input (vs output)
            
        Returns:
            SafetyScore with overall assessment
        """
        # Run guardrails
        if is_input:
            guardrail_result = self.guardrails.check_input(text)
        else:
            guardrail_result = self.guardrails.check_output(text)
        
        # Run content filter
        filter_result = self.content_filter.check(text)
        
        # Calculate overall score
        guardrail_score = 1.0 if guardrail_result.passed else 0.0
        filter_score = filter_result.confidence if filter_result.is_safe else 0.0
        
        overall_score = (guardrail_score + filter_score) / 2
        passed = guardrail_result.passed and filter_result.is_safe
        
        return SafetyScore(
            score=overall_score,
            passed=passed,
            guardrail_result=guardrail_result,
            filter_result=filter_result,
            details={
                "guardrail_violations": guardrail_result.violations,
                "content_category": filter_result.category.value,
                "filter_scores": filter_result.scores,
            },
        )
    
    def evaluate_conversation(
        self,
        messages: List[Dict[str, str]],
    ) -> List[SafetyScore]:
        """Evaluate a conversation for safety."""
        results = []
        for msg in messages:
            is_input = msg.get("role") == "user"
            content = msg.get("content", "")
            results.append(self.evaluate(content, is_input=is_input))
        return results
    
    def get_safety_report(self, scores: List[SafetyScore]) -> Dict[str, Any]:
        """Generate safety report from multiple evaluations."""
        total = len(scores)
        passed = sum(1 for s in scores if s.passed)
        avg_score = sum(s.score for s in scores) / total if total > 0 else 0.0
        
        return {
            "total_evaluated": total,
            "passed": passed,
            "failed": total - passed,
            "pass_rate": passed / total if total > 0 else 0.0,
            "average_score": avg_score,
            "all_passed": passed == total,
        }
