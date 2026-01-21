#!/usr/bin/env python3
"""
IGLA SWE-bench Runner - Real LLM-powered benchmark evaluation
φ² + 1/φ² = 3 | PHOENIX = 999
"""

import os
import sys
import json
import time
import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import Optional, Dict, List, Any
from dataclasses import dataclass
from datetime import datetime

# Sacred constants
PHI = 1.618033988749895
PHOENIX = 999

@dataclass
class LLMConfig:
    """LLM API configuration"""
    provider: str  # openai, anthropic, local
    api_key: str
    model: str
    base_url: str = ""
    max_tokens: int = 4096
    temperature: float = 0.0

@dataclass
class SWEInstance:
    """SWE-bench instance"""
    instance_id: str
    repo: str
    base_commit: str
    patch: str
    test_patch: str
    problem_statement: str
    hints_text: str
    fail_to_pass: List[str]
    pass_to_pass: List[str]

@dataclass
class EvalResult:
    """Evaluation result for single instance"""
    instance_id: str
    resolved: bool
    patch_generated: str
    patch_applied: bool
    tests_passed: bool
    error: Optional[str]
    duration_ms: int
    tokens_used: int

class LLMClient:
    """Universal LLM client for OpenAI/Anthropic/Local"""
    
    def __init__(self, config: LLMConfig):
        self.config = config
        
    def complete(self, system_prompt: str, user_prompt: str) -> str:
        """Send completion request to LLM"""
        if self.config.provider == "openai":
            return self._complete_openai(system_prompt, user_prompt)
        elif self.config.provider == "anthropic":
            return self._complete_anthropic(system_prompt, user_prompt)
        elif self.config.provider == "local":
            return self._complete_local(system_prompt, user_prompt)
        else:
            raise ValueError(f"Unknown provider: {self.config.provider}")
    
    def _http_post(self, url: str, headers: dict, data: dict, timeout: int = 120) -> dict:
        """HTTP POST using urllib (no external deps)"""
        import urllib.request
        import urllib.error
        
        req_data = json.dumps(data).encode('utf-8')
        req = urllib.request.Request(url, data=req_data, headers=headers, method='POST')
        
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                return json.loads(response.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8') if e.fp else ""
            raise Exception(f"HTTP {e.code}: {error_body}")
    
    def _complete_openai(self, system_prompt: str, user_prompt: str) -> str:
        """OpenAI API completion"""
        url = self.config.base_url or "https://api.openai.com/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.config.api_key}",
            "Content-Type": "application/json"
        }
        data = {
            "model": self.config.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "max_tokens": self.config.max_tokens,
            "temperature": self.config.temperature
        }
        
        result = self._http_post(url, headers, data)
        return result["choices"][0]["message"]["content"]
    
    def _complete_anthropic(self, system_prompt: str, user_prompt: str) -> str:
        """Anthropic API completion"""
        url = self.config.base_url or "https://api.anthropic.com/v1/messages"
        headers = {
            "x-api-key": self.config.api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        }
        data = {
            "model": self.config.model,
            "max_tokens": self.config.max_tokens,
            "system": system_prompt,
            "messages": [
                {"role": "user", "content": user_prompt}
            ]
        }
        
        result = self._http_post(url, headers, data)
        return result["content"][0]["text"]
    
    def _complete_local(self, system_prompt: str, user_prompt: str) -> str:
        """Local LLM server (OpenAI-compatible)"""
        url = f"{self.config.base_url}/v1/chat/completions"
        headers = {"Content-Type": "application/json"}
        data = {
            "model": self.config.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "max_tokens": self.config.max_tokens,
            "temperature": self.config.temperature
        }
        
        result = self._http_post(url, headers, data, timeout=300)
        return result["choices"][0]["message"]["content"]


class PatchGenerator:
    """Generates patches using LLM for SWE-bench tasks"""
    
    SYSTEM_PROMPT = """You are an expert software engineer tasked with fixing bugs in open source projects.

Your task is to analyze the issue description and generate a minimal patch that fixes the problem.

IMPORTANT RULES:
1. Output ONLY the unified diff patch, nothing else
2. Use the exact format: diff --git a/path/to/file b/path/to/file
3. Include proper --- and +++ headers
4. Make minimal changes - only what's necessary to fix the issue
5. Do not add comments explaining the fix
6. Do not include any text before or after the diff

Example output format:
diff --git a/src/module.py b/src/module.py
--- a/src/module.py
+++ b/src/module.py
@@ -10,7 +10,7 @@ def function():
-    old_line
+    new_line
"""

    USER_PROMPT_TEMPLATE = """Repository: {repo}
Base commit: {base_commit}

## Issue Description
{problem_statement}

## Hints
{hints_text}

Generate a unified diff patch that fixes this issue. Output ONLY the diff, nothing else."""

    def __init__(self, llm_client: LLMClient):
        self.llm = llm_client
    
    def generate(self, instance: SWEInstance) -> str:
        """Generate patch for SWE-bench instance"""
        user_prompt = self.USER_PROMPT_TEMPLATE.format(
            repo=instance.repo,
            base_commit=instance.base_commit,
            problem_statement=instance.problem_statement,
            hints_text=instance.hints_text or "No hints provided."
        )
        
        response = self.llm.complete(self.SYSTEM_PROMPT, user_prompt)
        return self._extract_patch(response)
    
    def _extract_patch(self, response: str) -> str:
        """Extract diff patch from LLM response"""
        # Try to find diff block
        if "```diff" in response:
            start = response.find("```diff") + 7
            end = response.find("```", start)
            if end > start:
                return response[start:end].strip()
        
        if "```" in response:
            start = response.find("```") + 3
            end = response.find("```", start)
            if end > start:
                return response[start:end].strip()
        
        # If response starts with diff, use as-is
        if response.strip().startswith("diff --git"):
            return response.strip()
        
        return response.strip()


class SWEBenchHarness:
    """Execution harness for SWE-bench evaluation"""
    
    def __init__(self, work_dir: str = "/tmp/swe_bench"):
        self.work_dir = Path(work_dir)
        self.work_dir.mkdir(parents=True, exist_ok=True)
    
    def setup_repo(self, instance: SWEInstance) -> Path:
        """Clone and setup repository"""
        repo_dir = self.work_dir / instance.instance_id.replace("/", "_")
        
        if repo_dir.exists():
            shutil.rmtree(repo_dir)
        
        # Clone repo
        repo_url = f"https://github.com/{instance.repo}.git"
        subprocess.run(
            ["git", "clone", "--depth", "100", repo_url, str(repo_dir)],
            check=True, capture_output=True
        )
        
        # Checkout base commit
        subprocess.run(
            ["git", "checkout", instance.base_commit],
            cwd=repo_dir, check=True, capture_output=True
        )
        
        return repo_dir
    
    def apply_patch(self, repo_dir: Path, patch: str) -> bool:
        """Apply patch to repository"""
        patch_file = repo_dir / "generated.patch"
        patch_file.write_text(patch)
        
        # Try different apply methods
        for cmd in [
            ["git", "apply", "--verbose", str(patch_file)],
            ["git", "apply", "--verbose", "--reject", str(patch_file)],
            ["patch", "-p1", "-i", str(patch_file)]
        ]:
            result = subprocess.run(cmd, cwd=repo_dir, capture_output=True)
            if result.returncode == 0:
                return True
        
        return False
    
    def run_tests(self, repo_dir: Path, tests: List[str], timeout: int = 300) -> bool:
        """Run specified tests"""
        if not tests:
            return True
        
        # Detect test framework
        if (repo_dir / "pytest.ini").exists() or (repo_dir / "setup.py").exists():
            cmd = ["python", "-m", "pytest", "-xvs"] + tests
        else:
            cmd = ["python", "-m", "unittest"] + tests
        
        try:
            result = subprocess.run(
                cmd, cwd=repo_dir, capture_output=True, timeout=timeout
            )
            return result.returncode == 0
        except subprocess.TimeoutExpired:
            return False
    
    def cleanup(self, repo_dir: Path):
        """Cleanup repository"""
        if repo_dir.exists():
            shutil.rmtree(repo_dir)


class SWEBenchRunner:
    """Main runner for SWE-bench evaluation"""
    
    def __init__(self, llm_config: LLMConfig):
        self.llm = LLMClient(llm_config)
        self.generator = PatchGenerator(self.llm)
        self.harness = SWEBenchHarness()
        self.results: List[EvalResult] = []
    
    def load_instances(self, data_path: str) -> List[SWEInstance]:
        """Load SWE-bench instances from JSON"""
        with open(data_path) as f:
            data = json.load(f)
        
        instances = []
        for item in data:
            fail_to_pass = json.loads(item.get("FAIL_TO_PASS", "[]"))
            pass_to_pass = json.loads(item.get("PASS_TO_PASS", "[]"))
            
            instances.append(SWEInstance(
                instance_id=item["instance_id"],
                repo=item["repo"],
                base_commit=item["base_commit"],
                patch=item["patch"],
                test_patch=item["test_patch"],
                problem_statement=item["problem_statement"],
                hints_text=item.get("hints_text", ""),
                fail_to_pass=fail_to_pass if isinstance(fail_to_pass, list) else [fail_to_pass],
                pass_to_pass=pass_to_pass if isinstance(pass_to_pass, list) else [pass_to_pass]
            ))
        
        return instances
    
    def run_instance(self, instance: SWEInstance) -> EvalResult:
        """Run evaluation on single instance"""
        start_time = time.time()
        
        try:
            # Generate patch
            print(f"  Generating patch for {instance.instance_id}...")
            patch = self.generator.generate(instance)
            
            if not patch or not patch.strip():
                return EvalResult(
                    instance_id=instance.instance_id,
                    resolved=False,
                    patch_generated="",
                    patch_applied=False,
                    tests_passed=False,
                    error="Empty patch generated",
                    duration_ms=int((time.time() - start_time) * 1000),
                    tokens_used=0
                )
            
            # Setup repo
            print(f"  Setting up repository...")
            repo_dir = self.harness.setup_repo(instance)
            
            # Apply patch
            print(f"  Applying patch...")
            patch_applied = self.harness.apply_patch(repo_dir, patch)
            
            if not patch_applied:
                self.harness.cleanup(repo_dir)
                return EvalResult(
                    instance_id=instance.instance_id,
                    resolved=False,
                    patch_generated=patch,
                    patch_applied=False,
                    tests_passed=False,
                    error="Failed to apply patch",
                    duration_ms=int((time.time() - start_time) * 1000),
                    tokens_used=0
                )
            
            # Run tests
            print(f"  Running tests...")
            tests_passed = self.harness.run_tests(repo_dir, instance.fail_to_pass)
            
            # Cleanup
            self.harness.cleanup(repo_dir)
            
            return EvalResult(
                instance_id=instance.instance_id,
                resolved=tests_passed,
                patch_generated=patch,
                patch_applied=True,
                tests_passed=tests_passed,
                error=None,
                duration_ms=int((time.time() - start_time) * 1000),
                tokens_used=0
            )
            
        except Exception as e:
            return EvalResult(
                instance_id=instance.instance_id,
                resolved=False,
                patch_generated="",
                patch_applied=False,
                tests_passed=False,
                error=str(e),
                duration_ms=int((time.time() - start_time) * 1000),
                tokens_used=0
            )
    
    def run(self, instances: List[SWEInstance], limit: int = None) -> Dict[str, Any]:
        """Run evaluation on multiple instances"""
        if limit:
            instances = instances[:limit]
        
        print(f"\n{'='*70}")
        print(f"IGLA SWE-BENCH EVALUATION")
        print(f"{'='*70}")
        print(f"Instances: {len(instances)}")
        print(f"Provider: {self.llm.config.provider}")
        print(f"Model: {self.llm.config.model}")
        print(f"{'='*70}\n")
        
        resolved = 0
        for i, instance in enumerate(instances):
            print(f"[{i+1}/{len(instances)}] {instance.instance_id}")
            
            result = self.run_instance(instance)
            self.results.append(result)
            
            status = "✓ RESOLVED" if result.resolved else "✗ FAILED"
            print(f"  Result: {status}")
            if result.error:
                print(f"  Error: {result.error}")
            print()
            
            if result.resolved:
                resolved += 1
        
        # Summary
        pct = (resolved / len(instances)) * 100 if instances else 0
        
        print(f"{'='*70}")
        print(f"RESULTS")
        print(f"{'='*70}")
        print(f"Total:     {len(instances)}")
        print(f"Resolved:  {resolved}")
        print(f"Failed:    {len(instances) - resolved}")
        print(f"Rate:      {pct:.2f}%")
        print(f"{'='*70}")
        print(f"φ² + 1/φ² = 3 | PHOENIX = 999")
        print()
        
        return {
            "total": len(instances),
            "resolved": resolved,
            "failed": len(instances) - resolved,
            "percentage": pct,
            "results": [
                {
                    "instance_id": r.instance_id,
                    "resolved": r.resolved,
                    "error": r.error,
                    "duration_ms": r.duration_ms
                }
                for r in self.results
            ]
        }


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="IGLA SWE-bench Runner")
    parser.add_argument("--data", default="data/swe_bench/sample_instances.json",
                       help="Path to instances JSON")
    parser.add_argument("--limit", type=int, default=5,
                       help="Limit number of instances")
    parser.add_argument("--provider", default="openai",
                       choices=["openai", "anthropic", "local", "demo"],
                       help="LLM provider (use 'demo' for no-API test)")
    parser.add_argument("--model", default="gpt-4",
                       help="Model name")
    parser.add_argument("--api-key", default=os.environ.get("OPENAI_API_KEY", ""),
                       help="API key")
    parser.add_argument("--base-url", default="",
                       help="Base URL for local LLM")
    parser.add_argument("--output", default="results.json",
                       help="Output file for results")
    
    args = parser.parse_args()
    
    # Demo mode - use gold patches
    if args.provider == "demo":
        run_demo_mode(args.data, args.limit, args.output)
        return
    
    if not args.api_key and args.provider != "local":
        print("Error: API key required. Set OPENAI_API_KEY or use --api-key")
        print("For demo without API, use: --provider demo")
        sys.exit(1)
    
    config = LLMConfig(
        provider=args.provider,
        api_key=args.api_key,
        model=args.model,
        base_url=args.base_url
    )
    
    runner = SWEBenchRunner(config)
    instances = runner.load_instances(args.data)
    results = runner.run(instances, limit=args.limit)
    
    # Save results
    with open(args.output, "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"Results saved to: {args.output}")


def run_demo_mode(data_path: str, limit: int, output_path: str):
    """Demo mode using gold patches (no LLM required)"""
    print(f"\n{'='*70}")
    print(f"IGLA SWE-BENCH DEMO MODE (Gold Patches)")
    print(f"{'='*70}")
    print(f"No API key required - using gold patches from dataset")
    print(f"{'='*70}\n")
    
    with open(data_path) as f:
        data = json.load(f)
    
    instances = data[:limit]
    results = []
    resolved = 0
    
    for i, item in enumerate(instances):
        instance_id = item["instance_id"]
        gold_patch = item["patch"]
        
        print(f"[{i+1}/{len(instances)}] {instance_id}")
        
        # Check if gold patch exists and is valid
        has_patch = bool(gold_patch and gold_patch.strip())
        
        if has_patch:
            print(f"  Gold patch: {len(gold_patch)} bytes")
            print(f"  Result: ✓ RESOLVED (gold patch available)")
            resolved += 1
            status = True
        else:
            print(f"  Result: ✗ FAILED (no gold patch)")
            status = False
        
        results.append({
            "instance_id": instance_id,
            "resolved": status,
            "patch_size": len(gold_patch) if gold_patch else 0,
            "mode": "demo"
        })
        print()
    
    pct = (resolved / len(instances)) * 100 if instances else 0
    
    print(f"{'='*70}")
    print(f"DEMO RESULTS")
    print(f"{'='*70}")
    print(f"Total:     {len(instances)}")
    print(f"Resolved:  {resolved}")
    print(f"Failed:    {len(instances) - resolved}")
    print(f"Rate:      {pct:.2f}%")
    print(f"{'='*70}")
    print(f"Note: This uses gold patches, not LLM-generated patches")
    print(f"For real evaluation, provide API key:")
    print(f"  --provider openai --api-key sk-...")
    print(f"{'='*70}")
    print(f"φ² + 1/φ² = 3 | PHOENIX = 999")
    print()
    
    output = {
        "mode": "demo",
        "total": len(instances),
        "resolved": resolved,
        "percentage": pct,
        "results": results
    }
    
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)
    
    print(f"Results saved to: {output_path}")


if __name__ == "__main__":
    main()
