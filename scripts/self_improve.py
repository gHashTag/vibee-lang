#!/usr/bin/env python3
"""
IGLA Self-Improvement Loop
Reflexion-based iterative improvement for SWE Agent
φ² + 1/φ² = 3 | PHOENIX = 999
"""

import os
import sys
import json
import time
import re
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass, field, asdict
from datetime import datetime
from enum import Enum

# Sacred constants
PHI = 1.618033988749895
PHOENIX = 999


class FailureCategory(Enum):
    PATCH_SYNTAX = "patch_syntax"
    PATCH_APPLICATION = "patch_application"
    TEST_FAILURE = "test_failure"
    TIMEOUT = "timeout"
    DEPENDENCY_MISSING = "dependency_missing"
    LOGIC_ERROR = "logic_error"
    EDGE_CASE = "edge_case"
    REGRESSION = "regression"
    UNKNOWN = "unknown"


@dataclass
class Attempt:
    """Single attempt at solving a problem"""
    iteration: int
    patch: str
    test_passed: bool
    error_message: str
    reflection: str
    score: float
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())


@dataclass
class Experience:
    """Stored experience for memory"""
    id: str
    instance_id: str
    problem: str
    solution: str
    reflection: str
    success: bool
    score: float
    tags: List[str]
    timestamp: str


@dataclass
class FailureAnalysis:
    """Analysis of a failure"""
    category: FailureCategory
    root_cause: str
    suggested_fix: str
    confidence: float
    patterns_matched: List[str]


class FailureAnalyzer:
    """Analyzes failures to extract insights"""
    
    PATTERNS = {
        r"SyntaxError": (FailureCategory.PATCH_SYNTAX, "Syntax error in generated code"),
        r"IndentationError": (FailureCategory.PATCH_SYNTAX, "Indentation error in patch"),
        r"patch.*failed|FAILED.*Hunk": (FailureCategory.PATCH_APPLICATION, "Patch could not be applied"),
        r"AssertionError": (FailureCategory.TEST_FAILURE, "Test assertion failed"),
        r"TimeoutError|timed out": (FailureCategory.TIMEOUT, "Execution timed out"),
        r"ModuleNotFoundError|ImportError": (FailureCategory.DEPENDENCY_MISSING, "Missing dependency"),
        r"TypeError|ValueError|AttributeError": (FailureCategory.LOGIC_ERROR, "Logic error in code"),
        r"KeyError|IndexError": (FailureCategory.EDGE_CASE, "Edge case not handled"),
    }
    
    def analyze(self, error_output: str, test_output: str = "") -> FailureAnalysis:
        """Analyze failure and categorize it"""
        combined = f"{error_output}\n{test_output}"
        
        matched_patterns = []
        category = FailureCategory.UNKNOWN
        root_cause = "Unknown error"
        
        for pattern, (cat, cause) in self.PATTERNS.items():
            if re.search(pattern, combined, re.IGNORECASE):
                matched_patterns.append(pattern)
                category = cat
                root_cause = cause
                break
        
        suggested_fix = self._suggest_fix(category, combined)
        confidence = 0.8 if matched_patterns else 0.3
        
        return FailureAnalysis(
            category=category,
            root_cause=root_cause,
            suggested_fix=suggested_fix,
            confidence=confidence,
            patterns_matched=matched_patterns
        )
    
    def _suggest_fix(self, category: FailureCategory, error: str) -> str:
        """Suggest fix based on category"""
        suggestions = {
            FailureCategory.PATCH_SYNTAX: "Check syntax of generated code, ensure proper indentation",
            FailureCategory.PATCH_APPLICATION: "Verify patch format, check file paths match",
            FailureCategory.TEST_FAILURE: "Review test expectations, check edge cases",
            FailureCategory.TIMEOUT: "Optimize code, add early termination",
            FailureCategory.DEPENDENCY_MISSING: "Add missing imports or dependencies",
            FailureCategory.LOGIC_ERROR: "Review logic flow, check type handling",
            FailureCategory.EDGE_CASE: "Add bounds checking, handle None/empty cases",
            FailureCategory.REGRESSION: "Ensure changes don't break existing functionality",
            FailureCategory.UNKNOWN: "Review error message carefully",
        }
        return suggestions.get(category, "Review error and try again")


class ExperienceMemory:
    """Episodic memory for storing experiences"""
    
    def __init__(self, max_size: int = 1000):
        self.experiences: List[Experience] = []
        self.max_size = max_size
        self._id_counter = 0
    
    def store(self, instance_id: str, problem: str, solution: str, 
              reflection: str, success: bool, score: float, tags: List[str]) -> str:
        """Store new experience"""
        self._id_counter += 1
        exp_id = f"exp_{self._id_counter}"
        
        exp = Experience(
            id=exp_id,
            instance_id=instance_id,
            problem=problem,
            solution=solution,
            reflection=reflection,
            success=success,
            score=score,
            tags=tags,
            timestamp=datetime.now().isoformat()
        )
        
        self.experiences.append(exp)
        
        # Prune if needed
        if len(self.experiences) > self.max_size:
            self._prune()
        
        return exp_id
    
    def retrieve_similar(self, problem: str, limit: int = 5) -> List[Experience]:
        """Retrieve similar experiences"""
        # Simple keyword matching (would use embeddings in production)
        keywords = set(problem.lower().split())
        
        scored = []
        for exp in self.experiences:
            exp_keywords = set(exp.problem.lower().split())
            overlap = len(keywords & exp_keywords)
            if overlap > 0:
                scored.append((overlap, exp))
        
        scored.sort(key=lambda x: (-x[0], -x[1].score))
        return [exp for _, exp in scored[:limit]]
    
    def retrieve_successes(self, limit: int = 10) -> List[Experience]:
        """Retrieve successful experiences"""
        successes = [e for e in self.experiences if e.success]
        successes.sort(key=lambda x: -x.score)
        return successes[:limit]
    
    def retrieve_failures(self, limit: int = 10) -> List[Experience]:
        """Retrieve failed experiences"""
        failures = [e for e in self.experiences if not e.success]
        failures.sort(key=lambda x: x.score)  # Worst first
        return failures[:limit]
    
    def _prune(self):
        """Remove lowest-scored experiences"""
        self.experiences.sort(key=lambda x: -x.score)
        self.experiences = self.experiences[:self.max_size]
    
    def export_json(self) -> str:
        """Export memory to JSON"""
        return json.dumps([asdict(e) for e in self.experiences], indent=2)
    
    def import_json(self, data: str):
        """Import memory from JSON"""
        items = json.loads(data)
        for item in items:
            item['category'] = item.get('category', 'unknown')
            self.experiences.append(Experience(**item))


class ReflexionLoop:
    """Main self-improvement loop using Reflexion pattern"""
    
    def __init__(self, max_iterations: int = 5, improvement_threshold: float = 0.1):
        self.max_iterations = max_iterations
        self.improvement_threshold = improvement_threshold
        self.analyzer = FailureAnalyzer()
        self.memory = ExperienceMemory()
        self.attempts: List[Attempt] = []
    
    def generate_reflection(self, attempt: Attempt, analysis: FailureAnalysis) -> str:
        """Generate verbal reflection on failure"""
        reflection = f"""
Reflection on Attempt {attempt.iteration}:

WHAT HAPPENED:
- Test passed: {attempt.test_passed}
- Error category: {analysis.category.value}
- Root cause: {analysis.root_cause}

WHAT WENT WRONG:
{attempt.error_message[:500] if attempt.error_message else 'No error message'}

WHAT TO DO DIFFERENTLY:
- {analysis.suggested_fix}
- Confidence: {analysis.confidence:.0%}

KEY INSIGHT:
Based on this failure, I should focus on {analysis.root_cause.lower()} 
and ensure the next attempt addresses this specific issue.
"""
        return reflection.strip()
    
    def apply_reflection(self, previous_patch: str, reflection: str, 
                        problem: str, llm_client=None) -> str:
        """Apply reflection to generate improved patch"""
        # In production, this would call LLM with reflection context
        # For now, return template showing the pattern
        
        improved_prompt = f"""
Based on the following reflection, generate an improved patch:

PREVIOUS ATTEMPT REFLECTION:
{reflection}

ORIGINAL PROBLEM:
{problem}

Generate a new patch that addresses the issues identified in the reflection.
Output ONLY the unified diff patch.
"""
        
        if llm_client:
            return llm_client.complete(improved_prompt)
        
        # Demo: return modified patch
        return f"# Improved based on reflection\n{previous_patch}"
    
    def evaluate_attempt(self, attempt: Attempt) -> float:
        """Evaluate attempt and return score"""
        if attempt.test_passed:
            return 1.0
        
        # Partial credit based on error type
        analysis = self.analyzer.analyze(attempt.error_message)
        
        scores = {
            FailureCategory.PATCH_SYNTAX: 0.1,
            FailureCategory.PATCH_APPLICATION: 0.2,
            FailureCategory.TEST_FAILURE: 0.5,  # Close!
            FailureCategory.TIMEOUT: 0.3,
            FailureCategory.DEPENDENCY_MISSING: 0.2,
            FailureCategory.LOGIC_ERROR: 0.4,
            FailureCategory.EDGE_CASE: 0.6,  # Very close
            FailureCategory.REGRESSION: 0.3,
            FailureCategory.UNKNOWN: 0.1,
        }
        
        return scores.get(analysis.category, 0.1)
    
    def should_continue(self, attempts: List[Attempt]) -> Tuple[bool, str]:
        """Check if should continue iterating"""
        if not attempts:
            return True, "No attempts yet"
        
        if len(attempts) >= self.max_iterations:
            return False, f"Max iterations ({self.max_iterations}) reached"
        
        if attempts[-1].test_passed:
            return False, "Test passed!"
        
        # Check for improvement
        if len(attempts) >= 3:
            recent_scores = [a.score for a in attempts[-3:]]
            if max(recent_scores) - min(recent_scores) < self.improvement_threshold:
                return False, "No improvement in last 3 iterations"
        
        return True, "Continuing improvement"
    
    def run(self, problem: str, initial_patch: str, 
            test_func=None, llm_client=None) -> Dict[str, Any]:
        """Run full improvement loop"""
        print(f"\n{'='*70}")
        print(f"IGLA SELF-IMPROVEMENT LOOP (Reflexion)")
        print(f"{'='*70}")
        print(f"Max iterations: {self.max_iterations}")
        print(f"Improvement threshold: {self.improvement_threshold}")
        print(f"{'='*70}\n")
        
        self.attempts = []
        current_patch = initial_patch
        
        # Retrieve similar experiences
        similar = self.memory.retrieve_similar(problem, limit=3)
        if similar:
            print(f"Found {len(similar)} similar experiences in memory")
            for exp in similar:
                print(f"  - {exp.instance_id}: {'✓' if exp.success else '✗'} (score: {exp.score:.2f})")
            print()
        
        while True:
            iteration = len(self.attempts) + 1
            print(f"[Iteration {iteration}/{self.max_iterations}]")
            
            # Test current patch
            if test_func:
                test_passed, error_msg = test_func(current_patch)
            else:
                # Demo mode
                test_passed = iteration >= 3  # Succeed on 3rd try
                error_msg = "" if test_passed else f"Demo error for iteration {iteration}"
            
            # Analyze failure
            analysis = self.analyzer.analyze(error_msg)
            
            # Create attempt
            attempt = Attempt(
                iteration=iteration,
                patch=current_patch,
                test_passed=test_passed,
                error_message=error_msg,
                reflection="",
                score=0.0
            )
            
            # Evaluate
            attempt.score = self.evaluate_attempt(attempt)
            
            # Generate reflection if failed
            if not test_passed:
                attempt.reflection = self.generate_reflection(attempt, analysis)
                print(f"  Category: {analysis.category.value}")
                print(f"  Score: {attempt.score:.2f}")
                print(f"  Suggested: {analysis.suggested_fix}")
            else:
                attempt.reflection = "Success! No reflection needed."
                print(f"  ✓ TEST PASSED!")
            
            self.attempts.append(attempt)
            
            # Check if should continue
            should_continue, reason = self.should_continue(self.attempts)
            print(f"  Status: {reason}\n")
            
            if not should_continue:
                break
            
            # Apply reflection to improve
            current_patch = self.apply_reflection(
                current_patch, 
                attempt.reflection, 
                problem,
                llm_client
            )
        
        # Store experience
        best_attempt = max(self.attempts, key=lambda a: a.score)
        self.memory.store(
            instance_id="current",
            problem=problem,
            solution=best_attempt.patch,
            reflection=best_attempt.reflection,
            success=best_attempt.test_passed,
            score=best_attempt.score,
            tags=["swe-bench", "reflexion"]
        )
        
        # Results
        result = {
            "success": best_attempt.test_passed,
            "iterations": len(self.attempts),
            "best_score": best_attempt.score,
            "final_patch": best_attempt.patch,
            "improvement_history": [a.score for a in self.attempts],
            "reflections": [a.reflection for a in self.attempts if a.reflection]
        }
        
        print(f"{'='*70}")
        print(f"RESULTS")
        print(f"{'='*70}")
        print(f"Success: {result['success']}")
        print(f"Iterations: {result['iterations']}")
        print(f"Best score: {result['best_score']:.2f}")
        print(f"Improvement: {result['improvement_history']}")
        print(f"{'='*70}")
        print(f"φ² + 1/φ² = 3 | PHOENIX = {PHOENIX}")
        
        return result


def main():
    """Demo of self-improvement loop"""
    import argparse
    
    parser = argparse.ArgumentParser(description="IGLA Self-Improvement Loop")
    parser.add_argument("--max-iterations", type=int, default=5)
    parser.add_argument("--threshold", type=float, default=0.1)
    parser.add_argument("--output", default="improvement_results.json")
    
    args = parser.parse_args()
    
    # Demo problem
    problem = """
    Fix the username validator to reject trailing newlines.
    The regex r'^[\\w.@+-]+$' allows trailing newlines because $ matches before newline.
    Use \\Z instead of $ to fix this.
    """
    
    initial_patch = """
diff --git a/validators.py b/validators.py
--- a/validators.py
+++ b/validators.py
@@ -1,5 +1,5 @@
-    regex = r'^[\\w.@+-]+$'
+    regex = r'^[\\w.@+-]+$'  # TODO: fix newline issue
"""
    
    loop = ReflexionLoop(
        max_iterations=args.max_iterations,
        improvement_threshold=args.threshold
    )
    
    result = loop.run(problem, initial_patch)
    
    with open(args.output, "w") as f:
        json.dump(result, f, indent=2)
    
    print(f"\nResults saved to: {args.output}")


if __name__ == "__main__":
    main()
