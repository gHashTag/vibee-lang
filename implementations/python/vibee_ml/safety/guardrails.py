"""
Guardrails
==========

Input/output validation and safety constraints for LLM applications.
"""

from dataclasses import dataclass, field
from typing import List, Optional, Callable, Dict, Any
from enum import Enum
import re


class GuardrailAction(Enum):
    ALLOW = "allow"
    BLOCK = "block"
    WARN = "warn"
    MODIFY = "modify"


@dataclass
class GuardrailConfig:
    """Configuration for guardrails."""
    max_input_length: int = 4096
    max_output_length: int = 4096
    blocked_patterns: List[str] = field(default_factory=list)
    required_patterns: List[str] = field(default_factory=list)
    pii_detection: bool = True
    toxicity_threshold: float = 0.7
    custom_validators: List[Callable] = field(default_factory=list)


@dataclass
class GuardrailResult:
    """Result of guardrail check."""
    action: GuardrailAction
    passed: bool
    violations: List[str] = field(default_factory=list)
    modified_text: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


class Guardrails:
    """
    Input/output guardrails for LLM applications.
    
    Example:
        >>> guardrails = Guardrails(GuardrailConfig(pii_detection=True))
        >>> result = guardrails.check_input("My SSN is 123-45-6789")
        >>> print(result.passed)  # False
    """
    
    # Common PII patterns
    PII_PATTERNS = {
        "ssn": r"\b\d{3}-\d{2}-\d{4}\b",
        "credit_card": r"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b",
        "email": r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b",
        "phone": r"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b",
        "ip_address": r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b",
    }
    
    def __init__(self, config: Optional[GuardrailConfig] = None):
        self.config = config or GuardrailConfig()
        self._compiled_blocked = [re.compile(p, re.IGNORECASE) for p in self.config.blocked_patterns]
        self._compiled_required = [re.compile(p, re.IGNORECASE) for p in self.config.required_patterns]
        self._compiled_pii = {k: re.compile(v) for k, v in self.PII_PATTERNS.items()}
    
    def check_input(self, text: str) -> GuardrailResult:
        """Check input text against guardrails."""
        violations = []
        
        # Length check
        if len(text) > self.config.max_input_length:
            violations.append(f"Input exceeds max length ({len(text)} > {self.config.max_input_length})")
        
        # Blocked patterns
        for pattern in self._compiled_blocked:
            if pattern.search(text):
                violations.append(f"Blocked pattern found: {pattern.pattern}")
        
        # PII detection
        if self.config.pii_detection:
            pii_found = self._detect_pii(text)
            if pii_found:
                violations.extend([f"PII detected: {pii_type}" for pii_type in pii_found])
        
        # Custom validators
        for validator in self.config.custom_validators:
            try:
                result = validator(text)
                if not result:
                    violations.append(f"Custom validator failed: {validator.__name__}")
            except Exception as e:
                violations.append(f"Validator error: {e}")
        
        passed = len(violations) == 0
        action = GuardrailAction.ALLOW if passed else GuardrailAction.BLOCK
        
        return GuardrailResult(
            action=action,
            passed=passed,
            violations=violations,
        )
    
    def check_output(self, text: str) -> GuardrailResult:
        """Check output text against guardrails."""
        violations = []
        
        # Length check
        if len(text) > self.config.max_output_length:
            violations.append(f"Output exceeds max length ({len(text)} > {self.config.max_output_length})")
        
        # Blocked patterns
        for pattern in self._compiled_blocked:
            if pattern.search(text):
                violations.append(f"Blocked pattern in output: {pattern.pattern}")
        
        # Required patterns (for output)
        for pattern in self._compiled_required:
            if not pattern.search(text):
                violations.append(f"Required pattern missing: {pattern.pattern}")
        
        passed = len(violations) == 0
        action = GuardrailAction.ALLOW if passed else GuardrailAction.BLOCK
        
        return GuardrailResult(
            action=action,
            passed=passed,
            violations=violations,
        )
    
    def _detect_pii(self, text: str) -> List[str]:
        """Detect PII in text."""
        found = []
        for pii_type, pattern in self._compiled_pii.items():
            if pattern.search(text):
                found.append(pii_type)
        return found
    
    def redact_pii(self, text: str) -> str:
        """Redact PII from text."""
        result = text
        for pii_type, pattern in self._compiled_pii.items():
            result = pattern.sub(f"[REDACTED_{pii_type.upper()}]", result)
        return result
    
    def validate_json_output(self, text: str, schema: Dict[str, Any]) -> GuardrailResult:
        """Validate that output matches expected JSON schema."""
        import json
        violations = []
        
        try:
            data = json.loads(text)
            # Basic schema validation
            for key, expected_type in schema.items():
                if key not in data:
                    violations.append(f"Missing required key: {key}")
                elif not isinstance(data[key], expected_type):
                    violations.append(f"Invalid type for {key}: expected {expected_type.__name__}")
        except json.JSONDecodeError as e:
            violations.append(f"Invalid JSON: {e}")
        
        passed = len(violations) == 0
        return GuardrailResult(
            action=GuardrailAction.ALLOW if passed else GuardrailAction.BLOCK,
            passed=passed,
            violations=violations,
        )
