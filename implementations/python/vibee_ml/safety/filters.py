"""
Content Filters
===============

Toxicity and content classification filters.
"""

from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any
from enum import Enum


class ContentCategory(Enum):
    SAFE = "safe"
    TOXIC = "toxic"
    HATE = "hate"
    VIOLENCE = "violence"
    SEXUAL = "sexual"
    SELF_HARM = "self_harm"
    HARASSMENT = "harassment"


@dataclass
class FilterConfig:
    """Configuration for content filtering."""
    toxicity_threshold: float = 0.7
    categories_to_block: List[ContentCategory] = field(
        default_factory=lambda: [
            ContentCategory.TOXIC,
            ContentCategory.HATE,
            ContentCategory.VIOLENCE,
        ]
    )
    use_model: bool = False  # Use ML model for classification
    model_name: str = "unitary/toxic-bert"


@dataclass
class FilterResult:
    """Result of content filtering."""
    is_safe: bool
    category: ContentCategory
    confidence: float
    scores: Dict[str, float] = field(default_factory=dict)
    blocked: bool = False


class ContentFilter:
    """
    Content filtering for toxicity and harmful content.
    
    Example:
        >>> filter = ContentFilter()
        >>> result = filter.check("Hello, how are you?")
        >>> print(result.is_safe)  # True
    """
    
    # Simple keyword-based detection (for demo - use ML model in production)
    TOXIC_KEYWORDS = {
        "hate": ["hate", "racist", "bigot"],
        "violence": ["kill", "murder", "attack", "destroy"],
        "harassment": ["stupid", "idiot", "loser"],
    }
    
    def __init__(self, config: Optional[FilterConfig] = None):
        self.config = config or FilterConfig()
        self._model = None
        self._tokenizer = None
        
        if self.config.use_model:
            self._load_model()
    
    def _load_model(self):
        """Load toxicity classification model."""
        try:
            from transformers import AutoModelForSequenceClassification, AutoTokenizer
            self._tokenizer = AutoTokenizer.from_pretrained(self.config.model_name)
            self._model = AutoModelForSequenceClassification.from_pretrained(self.config.model_name)
        except ImportError:
            pass
    
    def check(self, text: str) -> FilterResult:
        """Check text for harmful content."""
        if self._model is not None:
            return self._check_with_model(text)
        return self._check_with_keywords(text)
    
    def _check_with_keywords(self, text: str) -> FilterResult:
        """Simple keyword-based checking."""
        text_lower = text.lower()
        scores = {}
        
        for category, keywords in self.TOXIC_KEYWORDS.items():
            count = sum(1 for kw in keywords if kw in text_lower)
            scores[category] = min(count * 0.3, 1.0)
        
        max_category = max(scores, key=scores.get) if scores else "safe"
        max_score = scores.get(max_category, 0.0)
        
        if max_score >= self.config.toxicity_threshold:
            category = ContentCategory(max_category)
            is_safe = False
        else:
            category = ContentCategory.SAFE
            is_safe = True
        
        blocked = category in self.config.categories_to_block
        
        return FilterResult(
            is_safe=is_safe,
            category=category,
            confidence=max_score if not is_safe else 1.0 - max_score,
            scores=scores,
            blocked=blocked,
        )
    
    def _check_with_model(self, text: str) -> FilterResult:
        """ML model-based checking."""
        import torch
        
        inputs = self._tokenizer(text, return_tensors="pt", truncation=True, max_length=512)
        
        with torch.no_grad():
            outputs = self._model(**inputs)
            probs = torch.softmax(outputs.logits, dim=-1)
        
        # Assuming binary classification (toxic/not toxic)
        toxic_prob = probs[0][1].item()
        
        is_safe = toxic_prob < self.config.toxicity_threshold
        category = ContentCategory.SAFE if is_safe else ContentCategory.TOXIC
        
        return FilterResult(
            is_safe=is_safe,
            category=category,
            confidence=1.0 - toxic_prob if is_safe else toxic_prob,
            scores={"toxic": toxic_prob, "safe": 1.0 - toxic_prob},
            blocked=not is_safe,
        )
    
    def batch_check(self, texts: List[str]) -> List[FilterResult]:
        """Check multiple texts."""
        return [self.check(text) for text in texts]
