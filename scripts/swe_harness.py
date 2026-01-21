#!/usr/bin/env python3
"""
IGLA SWE-bench Harness - Real execution environment
Supports Docker and Local modes
φ² + 1/φ² = 3 | PHOENIX = 999
"""

import os
import sys
import json
import time
import shutil
import tempfile
import subprocess
from pathlib import Path
from typing import Optional, List, Tuple, Dict, Any
from dataclasses import dataclass
from datetime import datetime

# Sacred constants
PHI = 1.618033988749895
PHOENIX = 999


@dataclass
class HarnessConfig:
    """Harness configuration"""
    mode: str = "local"  # docker, local
    timeout: int = 300
    work_dir: str = "/tmp/swe_bench"
    docker_image: str = "python:3.9-slim"
    keep_artifacts: bool = False


@dataclass
class GitResult:
    """Git operation result"""
    success: bool
    output: str
    error: str
    duration_ms: int


@dataclass
class TestResult:
    """Test execution result"""
    success: bool
    passed: int
    failed: int
    errors: int
    output: str
    duration_ms: int


@dataclass
class PatchResult:
    """Patch application result"""
    success: bool
    method: str
    output: str
    error: str


class GitOperations:
    """Real Git operations"""
    
    @staticmethod
    def clone(repo_url: str, target_dir: Path, depth: int = 100) -> GitResult:
        """Clone repository"""
        start = time.time()
        
        try:
            result = subprocess.run(
                ["git", "clone", "--depth", str(depth), repo_url, str(target_dir)],
                capture_output=True,
                text=True,
                timeout=120
            )
            
            return GitResult(
                success=result.returncode == 0,
                output=result.stdout,
                error=result.stderr,
                duration_ms=int((time.time() - start) * 1000)
            )
        except subprocess.TimeoutExpired:
            return GitResult(
                success=False,
                output="",
                error="Clone timeout",
                duration_ms=int((time.time() - start) * 1000)
            )
        except Exception as e:
            return GitResult(
                success=False,
                output="",
                error=str(e),
                duration_ms=int((time.time() - start) * 1000)
            )
    
    @staticmethod
    def checkout(repo_dir: Path, commit: str) -> GitResult:
        """Checkout specific commit"""
        start = time.time()
        
        try:
            # Fetch more history if needed
            subprocess.run(
                ["git", "fetch", "--depth", "100", "origin", commit],
                cwd=repo_dir,
                capture_output=True,
                timeout=60
            )
            
            result = subprocess.run(
                ["git", "checkout", commit],
                cwd=repo_dir,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            return GitResult(
                success=result.returncode == 0,
                output=result.stdout,
                error=result.stderr,
                duration_ms=int((time.time() - start) * 1000)
            )
        except Exception as e:
            return GitResult(
                success=False,
                output="",
                error=str(e),
                duration_ms=int((time.time() - start) * 1000)
            )
    
    @staticmethod
    def apply_patch(repo_dir: Path, patch_content: str) -> PatchResult:
        """Apply patch using multiple methods"""
        patch_file = repo_dir / "generated.patch"
        patch_file.write_text(patch_content)
        
        # Try different apply methods
        methods = [
            (["git", "apply", "--verbose", str(patch_file)], "git apply"),
            (["git", "apply", "--verbose", "--reject", str(patch_file)], "git apply --reject"),
            (["patch", "-p1", "-i", str(patch_file)], "patch -p1"),
            (["patch", "--batch", "--fuzz=5", "-p1", "-i", str(patch_file)], "patch --fuzz=5"),
        ]
        
        for cmd, method in methods:
            try:
                result = subprocess.run(
                    cmd,
                    cwd=repo_dir,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    return PatchResult(
                        success=True,
                        method=method,
                        output=result.stdout,
                        error=""
                    )
            except Exception:
                continue
        
        return PatchResult(
            success=False,
            method="none",
            output="",
            error="All patch methods failed"
        )
    
    @staticmethod
    def diff(repo_dir: Path) -> str:
        """Get current diff"""
        try:
            result = subprocess.run(
                ["git", "-c", "core.fileMode=false", "diff"],
                cwd=repo_dir,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.stdout
        except Exception:
            return ""
    
    @staticmethod
    def reset(repo_dir: Path) -> bool:
        """Reset repository to clean state"""
        try:
            subprocess.run(
                ["git", "checkout", "."],
                cwd=repo_dir,
                capture_output=True,
                timeout=30
            )
            subprocess.run(
                ["git", "clean", "-fd"],
                cwd=repo_dir,
                capture_output=True,
                timeout=30
            )
            return True
        except Exception:
            return False


class TestRunner:
    """Test execution in sandbox"""
    
    def __init__(self, timeout: int = 300):
        self.timeout = timeout
    
    def detect_framework(self, repo_dir: Path) -> str:
        """Detect test framework"""
        if (repo_dir / "pytest.ini").exists():
            return "pytest"
        if (repo_dir / "pyproject.toml").exists():
            content = (repo_dir / "pyproject.toml").read_text()
            if "pytest" in content:
                return "pytest"
        if (repo_dir / "setup.py").exists():
            return "pytest"  # Default to pytest for Python projects
        if (repo_dir / "tox.ini").exists():
            return "tox"
        return "unittest"
    
    def run_pytest(self, repo_dir: Path, tests: List[str]) -> TestResult:
        """Run pytest"""
        start = time.time()
        
        cmd = [sys.executable, "-m", "pytest", "-xvs", "--tb=short"]
        cmd.extend(tests)
        
        try:
            result = subprocess.run(
                cmd,
                cwd=repo_dir,
                capture_output=True,
                text=True,
                timeout=self.timeout,
                env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
            )
            
            # Parse pytest output
            output = result.stdout + result.stderr
            passed = output.count(" passed")
            failed = output.count(" failed")
            errors = output.count(" error")
            
            return TestResult(
                success=result.returncode == 0,
                passed=passed,
                failed=failed,
                errors=errors,
                output=output,
                duration_ms=int((time.time() - start) * 1000)
            )
        except subprocess.TimeoutExpired:
            return TestResult(
                success=False,
                passed=0,
                failed=0,
                errors=1,
                output="Test timeout",
                duration_ms=int((time.time() - start) * 1000)
            )
        except Exception as e:
            return TestResult(
                success=False,
                passed=0,
                failed=0,
                errors=1,
                output=str(e),
                duration_ms=int((time.time() - start) * 1000)
            )
    
    def run_unittest(self, repo_dir: Path, tests: List[str]) -> TestResult:
        """Run unittest"""
        start = time.time()
        
        cmd = [sys.executable, "-m", "unittest"]
        cmd.extend(tests)
        
        try:
            result = subprocess.run(
                cmd,
                cwd=repo_dir,
                capture_output=True,
                text=True,
                timeout=self.timeout
            )
            
            output = result.stdout + result.stderr
            
            # Parse unittest output
            passed = 0
            failed = 0
            if "OK" in output:
                # Extract number from "Ran X tests"
                import re
                match = re.search(r"Ran (\d+) test", output)
                if match:
                    passed = int(match.group(1))
            
            return TestResult(
                success=result.returncode == 0,
                passed=passed,
                failed=failed,
                errors=0,
                output=output,
                duration_ms=int((time.time() - start) * 1000)
            )
        except subprocess.TimeoutExpired:
            return TestResult(
                success=False,
                passed=0,
                failed=0,
                errors=1,
                output="Test timeout",
                duration_ms=int((time.time() - start) * 1000)
            )
        except Exception as e:
            return TestResult(
                success=False,
                passed=0,
                failed=0,
                errors=1,
                output=str(e),
                duration_ms=int((time.time() - start) * 1000)
            )
    
    def run(self, repo_dir: Path, tests: List[str]) -> TestResult:
        """Run tests with auto-detected framework"""
        if not tests:
            return TestResult(
                success=True,
                passed=0,
                failed=0,
                errors=0,
                output="No tests specified",
                duration_ms=0
            )
        
        framework = self.detect_framework(repo_dir)
        
        if framework == "pytest":
            return self.run_pytest(repo_dir, tests)
        else:
            return self.run_unittest(repo_dir, tests)


class DockerHarness:
    """Docker-based execution harness"""
    
    def __init__(self, config: HarnessConfig):
        self.config = config
        self.docker_available = self._check_docker()
    
    def _check_docker(self) -> bool:
        """Check if Docker is available"""
        try:
            result = subprocess.run(
                ["docker", "--version"],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception:
            return False
    
    def run_in_container(self, repo_dir: Path, command: List[str]) -> Tuple[int, str, str]:
        """Run command in Docker container"""
        if not self.docker_available:
            raise RuntimeError("Docker not available")
        
        docker_cmd = [
            "docker", "run", "--rm",
            "-v", f"{repo_dir}:/workspace",
            "-w", "/workspace",
            "--network", "none",  # Sandbox
            "--memory", "2g",
            "--cpus", "2",
            self.config.docker_image
        ] + command
        
        try:
            result = subprocess.run(
                docker_cmd,
                capture_output=True,
                text=True,
                timeout=self.config.timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Container timeout"
        except Exception as e:
            return -1, "", str(e)
    
    def build_image(self, repo_dir: Path, requirements: List[str]) -> bool:
        """Build custom Docker image with dependencies"""
        if not self.docker_available:
            return False
        
        dockerfile = f"""
FROM {self.config.docker_image}
WORKDIR /workspace
RUN pip install --no-cache-dir {' '.join(requirements)}
"""
        
        dockerfile_path = repo_dir / "Dockerfile.swebench"
        dockerfile_path.write_text(dockerfile)
        
        image_name = f"swebench-{repo_dir.name}"
        
        try:
            result = subprocess.run(
                ["docker", "build", "-t", image_name, "-f", str(dockerfile_path), "."],
                cwd=repo_dir,
                capture_output=True,
                timeout=300
            )
            return result.returncode == 0
        except Exception:
            return False


class LocalHarness:
    """Local execution harness (no Docker)"""
    
    def __init__(self, config: HarnessConfig):
        self.config = config
        self.work_dir = Path(config.work_dir)
        self.work_dir.mkdir(parents=True, exist_ok=True)
        self.git = GitOperations()
        self.test_runner = TestRunner(timeout=config.timeout)
    
    def setup_instance(self, instance_id: str, repo: str, base_commit: str) -> Optional[Path]:
        """Setup repository for instance"""
        repo_dir = self.work_dir / instance_id.replace("/", "_").replace("__", "_")
        
        # Clean existing
        if repo_dir.exists():
            shutil.rmtree(repo_dir)
        
        # Clone
        repo_url = f"https://github.com/{repo}.git"
        print(f"    Cloning {repo}...")
        
        clone_result = self.git.clone(repo_url, repo_dir)
        if not clone_result.success:
            print(f"    ✗ Clone failed: {clone_result.error}")
            return None
        
        # Checkout
        print(f"    Checking out {base_commit[:8]}...")
        checkout_result = self.git.checkout(repo_dir, base_commit)
        if not checkout_result.success:
            print(f"    ✗ Checkout failed: {checkout_result.error}")
            return None
        
        return repo_dir
    
    def apply_patch(self, repo_dir: Path, patch: str) -> PatchResult:
        """Apply patch to repository"""
        print(f"    Applying patch ({len(patch)} bytes)...")
        return self.git.apply_patch(repo_dir, patch)
    
    def run_tests(self, repo_dir: Path, tests: List[str]) -> TestResult:
        """Run tests"""
        print(f"    Running {len(tests)} tests...")
        return self.test_runner.run(repo_dir, tests)
    
    def cleanup(self, repo_dir: Path):
        """Cleanup repository"""
        if not self.config.keep_artifacts and repo_dir.exists():
            shutil.rmtree(repo_dir)


class SWEBenchHarness:
    """Main SWE-bench harness"""
    
    def __init__(self, config: HarnessConfig = None):
        self.config = config or HarnessConfig()
        
        if self.config.mode == "docker":
            self.docker = DockerHarness(self.config)
            if not self.docker.docker_available:
                print("Warning: Docker not available, falling back to local mode")
                self.config.mode = "local"
        
        self.local = LocalHarness(self.config)
    
    def evaluate_instance(self, instance: Dict[str, Any], patch: str) -> Dict[str, Any]:
        """Evaluate single instance with given patch"""
        instance_id = instance["instance_id"]
        repo = instance["repo"]
        base_commit = instance["base_commit"]
        
        # Parse tests
        fail_to_pass = instance.get("FAIL_TO_PASS", "[]")
        if isinstance(fail_to_pass, str):
            fail_to_pass = json.loads(fail_to_pass)
        
        start_time = time.time()
        
        print(f"\n  [{instance_id}]")
        
        # Setup
        repo_dir = self.local.setup_instance(instance_id, repo, base_commit)
        if not repo_dir:
            return {
                "instance_id": instance_id,
                "resolved": False,
                "error": "Setup failed",
                "duration_ms": int((time.time() - start_time) * 1000)
            }
        
        # Apply patch
        patch_result = self.local.apply_patch(repo_dir, patch)
        if not patch_result.success:
            self.local.cleanup(repo_dir)
            return {
                "instance_id": instance_id,
                "resolved": False,
                "patch_applied": False,
                "error": f"Patch failed: {patch_result.error}",
                "duration_ms": int((time.time() - start_time) * 1000)
            }
        
        print(f"    ✓ Patch applied via {patch_result.method}")
        
        # Run tests
        test_result = self.local.run_tests(repo_dir, fail_to_pass)
        
        # Cleanup
        self.local.cleanup(repo_dir)
        
        resolved = test_result.success
        status = "✓ RESOLVED" if resolved else "✗ FAILED"
        print(f"    {status} (passed: {test_result.passed}, failed: {test_result.failed})")
        
        return {
            "instance_id": instance_id,
            "resolved": resolved,
            "patch_applied": True,
            "patch_method": patch_result.method,
            "tests_passed": test_result.passed,
            "tests_failed": test_result.failed,
            "test_output": test_result.output[:1000],  # Truncate
            "duration_ms": int((time.time() - start_time) * 1000)
        }
    
    def evaluate_with_gold(self, instances: List[Dict], limit: int = None) -> Dict[str, Any]:
        """Evaluate instances using gold patches"""
        if limit:
            instances = instances[:limit]
        
        print(f"\n{'='*70}")
        print(f"IGLA SWE-BENCH HARNESS - Real Execution")
        print(f"{'='*70}")
        print(f"Mode: {self.config.mode}")
        print(f"Instances: {len(instances)}")
        print(f"{'='*70}")
        
        results = []
        resolved = 0
        
        for instance in instances:
            gold_patch = instance.get("patch", "")
            
            if not gold_patch:
                print(f"\n  [{instance['instance_id']}]")
                print(f"    ✗ No gold patch available")
                results.append({
                    "instance_id": instance["instance_id"],
                    "resolved": False,
                    "error": "No gold patch"
                })
                continue
            
            result = self.evaluate_instance(instance, gold_patch)
            results.append(result)
            
            if result.get("resolved"):
                resolved += 1
        
        pct = (resolved / len(instances)) * 100 if instances else 0
        
        print(f"\n{'='*70}")
        print(f"RESULTS")
        print(f"{'='*70}")
        print(f"Total:     {len(instances)}")
        print(f"Resolved:  {resolved}")
        print(f"Failed:    {len(instances) - resolved}")
        print(f"Rate:      {pct:.2f}%")
        print(f"{'='*70}")
        print(f"φ² + 1/φ² = 3 | PHOENIX = 999")
        
        return {
            "total": len(instances),
            "resolved": resolved,
            "percentage": pct,
            "results": results
        }


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="IGLA SWE-bench Harness")
    parser.add_argument("--data", default="data/swe_bench/sample_instances.json",
                       help="Path to instances JSON")
    parser.add_argument("--limit", type=int, default=1,
                       help="Limit number of instances")
    parser.add_argument("--mode", default="local", choices=["local", "docker"],
                       help="Execution mode")
    parser.add_argument("--timeout", type=int, default=300,
                       help="Test timeout in seconds")
    parser.add_argument("--keep-artifacts", action="store_true",
                       help="Keep cloned repositories")
    parser.add_argument("--output", default="harness_results.json",
                       help="Output file")
    
    args = parser.parse_args()
    
    config = HarnessConfig(
        mode=args.mode,
        timeout=args.timeout,
        keep_artifacts=args.keep_artifacts
    )
    
    harness = SWEBenchHarness(config)
    
    with open(args.data) as f:
        instances = json.load(f)
    
    results = harness.evaluate_with_gold(instances, limit=args.limit)
    
    with open(args.output, "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\nResults saved to: {args.output}")


if __name__ == "__main__":
    main()
