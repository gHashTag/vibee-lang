"""
Data Filtering
==============

Quality filtering for training data.
"""

from dataclasses import dataclass, field
from typing import List, Optional, Callable, Dict, Any
import re


@dataclass
class FilterConfig:
    """Configuration for data filtering."""
    min_length: int = 50
    max_length: int = 100000
    min_words: int = 10
    max_words: int = 50000
    min_unique_ratio: float = 0.3  # Unique words / total words
    max_special_char_ratio: float = 0.3
    max_digit_ratio: float = 0.5
    language: Optional[str] = None  # Filter by language
    remove_urls: bool = True
    remove_emails: bool = True
    custom_filters: List[Callable[[str], bool]] = field(default_factory=list)


@dataclass
class FilterResult:
    """Result of filtering."""
    passed: bool
    text: str
    original_text: str
    reasons: List[str] = field(default_factory=list)
    stats: Dict[str, Any] = field(default_factory=dict)


class DataFilter:
    """
    Quality filtering for training data.
    
    Example:
        >>> filter = DataFilter()
        >>> results = filter.filter_batch(texts)
        >>> clean_texts = [r.text for r in results if r.passed]
    """
    
    URL_PATTERN = re.compile(r'https?://\S+|www\.\S+')
    EMAIL_PATTERN = re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b')
    
    def __init__(self, config: Optional[FilterConfig] = None):
        self.config = config or FilterConfig()
    
    def filter(self, text: str) -> FilterResult:
        """Filter a single text."""
        original = text
        reasons = []
        
        # Clean text
        if self.config.remove_urls:
            text = self.URL_PATTERN.sub('', text)
        if self.config.remove_emails:
            text = self.EMAIL_PATTERN.sub('', text)
        
        text = text.strip()
        
        # Calculate stats
        words = text.split()
        word_count = len(words)
        char_count = len(text)
        unique_words = len(set(w.lower() for w in words))
        unique_ratio = unique_words / word_count if word_count > 0 else 0
        
        special_chars = sum(1 for c in text if not c.isalnum() and not c.isspace())
        special_ratio = special_chars / char_count if char_count > 0 else 0
        
        digits = sum(1 for c in text if c.isdigit())
        digit_ratio = digits / char_count if char_count > 0 else 0
        
        stats = {
            "char_count": char_count,
            "word_count": word_count,
            "unique_words": unique_words,
            "unique_ratio": unique_ratio,
            "special_ratio": special_ratio,
            "digit_ratio": digit_ratio,
        }
        
        # Apply filters
        passed = True
        
        if char_count < self.config.min_length:
            passed = False
            reasons.append(f"Too short: {char_count} < {self.config.min_length}")
        
        if char_count > self.config.max_length:
            passed = False
            reasons.append(f"Too long: {char_count} > {self.config.max_length}")
        
        if word_count < self.config.min_words:
            passed = False
            reasons.append(f"Too few words: {word_count} < {self.config.min_words}")
        
        if word_count > self.config.max_words:
            passed = False
            reasons.append(f"Too many words: {word_count} > {self.config.max_words}")
        
        if unique_ratio < self.config.min_unique_ratio:
            passed = False
            reasons.append(f"Low diversity: {unique_ratio:.2f} < {self.config.min_unique_ratio}")
        
        if special_ratio > self.config.max_special_char_ratio:
            passed = False
            reasons.append(f"Too many special chars: {special_ratio:.2f}")
        
        if digit_ratio > self.config.max_digit_ratio:
            passed = False
            reasons.append(f"Too many digits: {digit_ratio:.2f}")
        
        # Custom filters
        for custom_filter in self.config.custom_filters:
            try:
                if not custom_filter(text):
                    passed = False
                    reasons.append(f"Custom filter failed: {custom_filter.__name__}")
            except Exception as e:
                reasons.append(f"Filter error: {e}")
        
        return FilterResult(
            passed=passed,
            text=text,
            original_text=original,
            reasons=reasons,
            stats=stats,
        )
    
    def filter_batch(self, texts: List[str]) -> List[FilterResult]:
        """Filter multiple texts."""
        return [self.filter(text) for text in texts]
    
    def get_stats(self, results: List[FilterResult]) -> Dict[str, Any]:
        """Get filtering statistics."""
        total = len(results)
        passed = sum(1 for r in results if r.passed)
        
        return {
            "total": total,
            "passed": passed,
            "filtered": total - passed,
            "pass_rate": passed / total if total > 0 else 0,
        }


def filter_quality(texts: List[str], **kwargs) -> List[str]:
    """Convenience function for quality filtering."""
    config = FilterConfig(**kwargs)
    data_filter = DataFilter(config)
    results = data_filter.filter_batch(texts)
    return [r.text for r in results if r.passed]
