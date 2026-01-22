#!/usr/bin/env python3
"""
IGLA MCP Server - Model Context Protocol server for SWE Agent
Provides tools for code generation, testing, and SWE-bench evaluation
φ² + 1/φ² = 3 | PHOENIX = 999
"""

import sys
import json
import os
import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import Any, Dict, List, Optional
from dataclasses import dataclass, asdict

# Sacred constants
PHI = 1.618033988749895
PHOENIX = 999

# MCP Protocol version
PROTOCOL_VERSION = "2024-11-05"

# Server info
SERVER_NAME = "igla-swe-agent"
SERVER_VERSION = "1.0.0"


@dataclass
class Tool:
    """MCP Tool definition"""
    name: str
    description: str
    inputSchema: Dict[str, Any]


@dataclass
class Resource:
    """MCP Resource definition"""
    uri: str
    name: str
    description: str
    mimeType: str


class MCPServer:
    """IGLA MCP Server implementation"""
    
    def __init__(self):
        self.tools = self._define_tools()
        self.resources = self._define_resources()
        self.data_dir = Path(__file__).parent.parent / "data" / "swe_bench"
        
    def _define_tools(self) -> List[Tool]:
        """Define available tools"""
        return [
            Tool(
                name="generate_patch",
                description="Generate a code patch to fix a GitHub issue. Uses IGLA SWE Agent with ReAct reasoning.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "repo": {
                            "type": "string",
                            "description": "Repository in format owner/repo (e.g., django/django)"
                        },
                        "issue_description": {
                            "type": "string",
                            "description": "Description of the issue to fix"
                        },
                        "hints": {
                            "type": "string",
                            "description": "Optional hints for fixing the issue"
                        },
                        "file_path": {
                            "type": "string",
                            "description": "Optional specific file to modify"
                        }
                    },
                    "required": ["repo", "issue_description"]
                }
            ),
            Tool(
                name="run_tests",
                description="Run tests in a repository to verify a fix",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "repo_path": {
                            "type": "string",
                            "description": "Path to the repository"
                        },
                        "tests": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "List of test names to run"
                        },
                        "timeout": {
                            "type": "integer",
                            "description": "Timeout in seconds (default: 300)"
                        }
                    },
                    "required": ["repo_path", "tests"]
                }
            ),
            Tool(
                name="analyze_code",
                description="Analyze code for issues, complexity, or patterns",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "file_path": {
                            "type": "string",
                            "description": "Path to the file to analyze"
                        },
                        "analysis_type": {
                            "type": "string",
                            "enum": ["complexity", "issues", "patterns", "dependencies"],
                            "description": "Type of analysis to perform"
                        }
                    },
                    "required": ["file_path", "analysis_type"]
                }
            ),
            Tool(
                name="git_operations",
                description="Perform git operations (clone, checkout, apply patch)",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "operation": {
                            "type": "string",
                            "enum": ["clone", "checkout", "apply_patch", "diff", "status"],
                            "description": "Git operation to perform"
                        },
                        "repo_url": {
                            "type": "string",
                            "description": "Repository URL (for clone)"
                        },
                        "repo_path": {
                            "type": "string",
                            "description": "Local repository path"
                        },
                        "commit": {
                            "type": "string",
                            "description": "Commit hash (for checkout)"
                        },
                        "patch": {
                            "type": "string",
                            "description": "Patch content (for apply_patch)"
                        }
                    },
                    "required": ["operation"]
                }
            ),
            Tool(
                name="swe_bench",
                description="Interact with SWE-bench dataset and evaluation",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "action": {
                            "type": "string",
                            "enum": ["list", "get", "evaluate"],
                            "description": "Action to perform"
                        },
                        "instance_id": {
                            "type": "string",
                            "description": "Instance ID (for get/evaluate)"
                        },
                        "patch": {
                            "type": "string",
                            "description": "Patch to evaluate (for evaluate)"
                        },
                        "limit": {
                            "type": "integer",
                            "description": "Limit results (for list)"
                        }
                    },
                    "required": ["action"]
                }
            ),
            Tool(
                name="search_code",
                description="Search for code patterns in a repository",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "repo_path": {
                            "type": "string",
                            "description": "Path to the repository"
                        },
                        "query": {
                            "type": "string",
                            "description": "Search query (regex supported)"
                        },
                        "file_pattern": {
                            "type": "string",
                            "description": "File pattern to search (e.g., *.py)"
                        }
                    },
                    "required": ["repo_path", "query"]
                }
            )
        ]
    
    def _define_resources(self) -> List[Resource]:
        """Define available resources"""
        return [
            Resource(
                uri="swe-bench://instances",
                name="SWE-bench Instances",
                description="List of SWE-bench instances for evaluation",
                mimeType="application/json"
            ),
            Resource(
                uri="igla://config",
                name="IGLA Configuration",
                description="Current IGLA SWE Agent configuration",
                mimeType="application/json"
            ),
            Resource(
                uri="igla://stats",
                name="IGLA Statistics",
                description="IGLA module and test statistics",
                mimeType="application/json"
            )
        ]
    
    def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle incoming MCP request"""
        method = request.get("method", "")
        params = request.get("params", {})
        request_id = request.get("id")
        
        try:
            if method == "initialize":
                result = self._handle_initialize(params)
            elif method == "tools/list":
                result = self._handle_tools_list()
            elif method == "tools/call":
                result = self._handle_tools_call(params)
            elif method == "resources/list":
                result = self._handle_resources_list()
            elif method == "resources/read":
                result = self._handle_resources_read(params)
            elif method == "prompts/list":
                result = self._handle_prompts_list()
            elif method == "prompts/get":
                result = self._handle_prompts_get(params)
            else:
                return self._error_response(request_id, -32601, f"Method not found: {method}")
            
            return self._success_response(request_id, result)
            
        except Exception as e:
            return self._error_response(request_id, -32603, str(e))
    
    def _handle_initialize(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle initialize request"""
        return {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {
                "tools": {},
                "resources": {},
                "prompts": {}
            },
            "serverInfo": {
                "name": SERVER_NAME,
                "version": SERVER_VERSION
            }
        }
    
    def _handle_tools_list(self) -> Dict[str, Any]:
        """Handle tools/list request"""
        return {
            "tools": [
                {
                    "name": t.name,
                    "description": t.description,
                    "inputSchema": t.inputSchema
                }
                for t in self.tools
            ]
        }
    
    def _handle_tools_call(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle tools/call request"""
        tool_name = params.get("name", "")
        arguments = params.get("arguments", {})
        
        if tool_name == "generate_patch":
            return self._tool_generate_patch(arguments)
        elif tool_name == "run_tests":
            return self._tool_run_tests(arguments)
        elif tool_name == "analyze_code":
            return self._tool_analyze_code(arguments)
        elif tool_name == "git_operations":
            return self._tool_git_operations(arguments)
        elif tool_name == "swe_bench":
            return self._tool_swe_bench(arguments)
        elif tool_name == "search_code":
            return self._tool_search_code(arguments)
        else:
            raise ValueError(f"Unknown tool: {tool_name}")
    
    def _handle_resources_list(self) -> Dict[str, Any]:
        """Handle resources/list request"""
        return {
            "resources": [
                {
                    "uri": r.uri,
                    "name": r.name,
                    "description": r.description,
                    "mimeType": r.mimeType
                }
                for r in self.resources
            ]
        }
    
    def _handle_resources_read(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle resources/read request"""
        uri = params.get("uri", "")
        
        if uri == "swe-bench://instances":
            return self._resource_swe_instances()
        elif uri == "igla://config":
            return self._resource_igla_config()
        elif uri == "igla://stats":
            return self._resource_igla_stats()
        else:
            raise ValueError(f"Unknown resource: {uri}")
    
    def _handle_prompts_list(self) -> Dict[str, Any]:
        """Handle prompts/list request"""
        return {
            "prompts": [
                {
                    "name": "swe_fix",
                    "description": "Generate a fix for a software engineering issue",
                    "arguments": [
                        {"name": "issue", "description": "Issue description", "required": True},
                        {"name": "repo", "description": "Repository name", "required": True}
                    ]
                },
                {
                    "name": "code_review",
                    "description": "Review code changes",
                    "arguments": [
                        {"name": "diff", "description": "Code diff to review", "required": True}
                    ]
                }
            ]
        }
    
    def _handle_prompts_get(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle prompts/get request"""
        name = params.get("name", "")
        arguments = params.get("arguments", {})
        
        if name == "swe_fix":
            return {
                "messages": [
                    {
                        "role": "user",
                        "content": {
                            "type": "text",
                            "text": f"""You are an expert software engineer. Fix the following issue:

Repository: {arguments.get('repo', 'unknown')}

Issue:
{arguments.get('issue', 'No issue provided')}

Generate a minimal unified diff patch that fixes this issue.
Output ONLY the diff, no explanations."""
                        }
                    }
                ]
            }
        elif name == "code_review":
            return {
                "messages": [
                    {
                        "role": "user",
                        "content": {
                            "type": "text",
                            "text": f"""Review the following code changes:

{arguments.get('diff', 'No diff provided')}

Provide feedback on:
1. Correctness
2. Code quality
3. Potential issues"""
                        }
                    }
                ]
            }
        else:
            raise ValueError(f"Unknown prompt: {name}")
    
    # Tool implementations
    
    def _tool_generate_patch(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Generate patch tool"""
        repo = args.get("repo", "")
        issue = args.get("issue_description", "")
        hints = args.get("hints", "")
        
        # This would call the actual LLM in production
        # For now, return a template response
        patch_template = f"""diff --git a/src/module.py b/src/module.py
--- a/src/module.py
+++ b/src/module.py
@@ -1,5 +1,5 @@
 # Module for {repo}
-# TODO: Fix issue
+# Fixed: {issue[:50]}...
 
 def main():
     pass
"""
        
        return {
            "content": [
                {
                    "type": "text",
                    "text": f"Generated patch for {repo}:\n\n```diff\n{patch_template}\n```\n\nNote: This is a template. Connect to LLM for real patch generation."
                }
            ]
        }
    
    def _tool_run_tests(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Run tests tool"""
        repo_path = args.get("repo_path", "")
        tests = args.get("tests", [])
        timeout = args.get("timeout", 300)
        
        if not os.path.exists(repo_path):
            return {
                "content": [{"type": "text", "text": f"Error: Repository path not found: {repo_path}"}],
                "isError": True
            }
        
        try:
            cmd = [sys.executable, "-m", "pytest", "-xvs"] + tests
            result = subprocess.run(
                cmd,
                cwd=repo_path,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            
            output = result.stdout + result.stderr
            success = result.returncode == 0
            
            return {
                "content": [
                    {
                        "type": "text",
                        "text": f"Test Results:\n\nStatus: {'PASSED' if success else 'FAILED'}\n\n{output[:2000]}"
                    }
                ],
                "isError": not success
            }
        except subprocess.TimeoutExpired:
            return {
                "content": [{"type": "text", "text": f"Error: Tests timed out after {timeout}s"}],
                "isError": True
            }
        except Exception as e:
            return {
                "content": [{"type": "text", "text": f"Error running tests: {e}"}],
                "isError": True
            }
    
    def _tool_analyze_code(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze code tool"""
        file_path = args.get("file_path", "")
        analysis_type = args.get("analysis_type", "issues")
        
        if not os.path.exists(file_path):
            return {
                "content": [{"type": "text", "text": f"Error: File not found: {file_path}"}],
                "isError": True
            }
        
        try:
            with open(file_path) as f:
                content = f.read()
            
            lines = content.split("\n")
            
            analysis = {
                "file": file_path,
                "lines": len(lines),
                "characters": len(content),
                "analysis_type": analysis_type
            }
            
            if analysis_type == "complexity":
                # Simple complexity metrics
                analysis["functions"] = content.count("def ")
                analysis["classes"] = content.count("class ")
                analysis["imports"] = content.count("import ")
            elif analysis_type == "issues":
                # Simple issue detection
                issues = []
                for i, line in enumerate(lines):
                    if "TODO" in line:
                        issues.append(f"Line {i+1}: TODO found")
                    if "FIXME" in line:
                        issues.append(f"Line {i+1}: FIXME found")
                    if len(line) > 120:
                        issues.append(f"Line {i+1}: Line too long ({len(line)} chars)")
                analysis["issues"] = issues
            
            return {
                "content": [
                    {
                        "type": "text",
                        "text": f"Code Analysis:\n\n{json.dumps(analysis, indent=2)}"
                    }
                ]
            }
        except Exception as e:
            return {
                "content": [{"type": "text", "text": f"Error analyzing code: {e}"}],
                "isError": True
            }
    
    def _tool_git_operations(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Git operations tool"""
        operation = args.get("operation", "")
        
        try:
            if operation == "clone":
                repo_url = args.get("repo_url", "")
                repo_path = args.get("repo_path", tempfile.mkdtemp())
                
                result = subprocess.run(
                    ["git", "clone", "--depth", "100", repo_url, repo_path],
                    capture_output=True,
                    text=True,
                    timeout=120
                )
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"Cloned {repo_url} to {repo_path}\n\n{result.stdout}"
                    }],
                    "isError": result.returncode != 0
                }
                
            elif operation == "checkout":
                repo_path = args.get("repo_path", "")
                commit = args.get("commit", "")
                
                result = subprocess.run(
                    ["git", "checkout", commit],
                    cwd=repo_path,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"Checked out {commit}\n\n{result.stdout}"
                    }],
                    "isError": result.returncode != 0
                }
                
            elif operation == "apply_patch":
                repo_path = args.get("repo_path", "")
                patch = args.get("patch", "")
                
                patch_file = Path(repo_path) / "temp.patch"
                patch_file.write_text(patch)
                
                result = subprocess.run(
                    ["git", "apply", "--verbose", str(patch_file)],
                    cwd=repo_path,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                patch_file.unlink()
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"Applied patch\n\n{result.stdout}"
                    }],
                    "isError": result.returncode != 0
                }
                
            elif operation == "diff":
                repo_path = args.get("repo_path", "")
                
                result = subprocess.run(
                    ["git", "diff"],
                    cwd=repo_path,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"Current diff:\n\n```diff\n{result.stdout}\n```"
                    }]
                }
                
            elif operation == "status":
                repo_path = args.get("repo_path", "")
                
                result = subprocess.run(
                    ["git", "status", "--short"],
                    cwd=repo_path,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"Git status:\n\n{result.stdout}"
                    }]
                }
            else:
                return {
                    "content": [{"type": "text", "text": f"Unknown operation: {operation}"}],
                    "isError": True
                }
                
        except Exception as e:
            return {
                "content": [{"type": "text", "text": f"Git error: {e}"}],
                "isError": True
            }
    
    def _tool_swe_bench(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """SWE-bench tool"""
        action = args.get("action", "")
        
        try:
            if action == "list":
                limit = args.get("limit", 10)
                instances = self._load_swe_instances()[:limit]
                
                summary = []
                for inst in instances:
                    summary.append({
                        "instance_id": inst["instance_id"],
                        "repo": inst["repo"],
                        "version": inst.get("version", "unknown")
                    })
                
                return {
                    "content": [{
                        "type": "text",
                        "text": f"SWE-bench instances ({len(summary)}):\n\n{json.dumps(summary, indent=2)}"
                    }]
                }
                
            elif action == "get":
                instance_id = args.get("instance_id", "")
                instances = self._load_swe_instances()
                
                for inst in instances:
                    if inst["instance_id"] == instance_id:
                        return {
                            "content": [{
                                "type": "text",
                                "text": f"Instance: {instance_id}\n\n{json.dumps(inst, indent=2)}"
                            }]
                        }
                
                return {
                    "content": [{"type": "text", "text": f"Instance not found: {instance_id}"}],
                    "isError": True
                }
                
            elif action == "evaluate":
                instance_id = args.get("instance_id", "")
                patch = args.get("patch", "")
                
                # Would run actual evaluation here
                return {
                    "content": [{
                        "type": "text",
                        "text": f"Evaluation for {instance_id}:\n\nPatch size: {len(patch)} bytes\nStatus: Evaluation requires harness setup"
                    }]
                }
            else:
                return {
                    "content": [{"type": "text", "text": f"Unknown action: {action}"}],
                    "isError": True
                }
                
        except Exception as e:
            return {
                "content": [{"type": "text", "text": f"SWE-bench error: {e}"}],
                "isError": True
            }
    
    def _tool_search_code(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Search code tool"""
        repo_path = args.get("repo_path", "")
        query = args.get("query", "")
        file_pattern = args.get("file_pattern", "*")
        
        try:
            result = subprocess.run(
                ["grep", "-rn", "--include", file_pattern, query, repo_path],
                capture_output=True,
                text=True,
                timeout=60
            )
            
            matches = result.stdout.strip().split("\n")[:20]  # Limit results
            
            return {
                "content": [{
                    "type": "text",
                    "text": f"Search results for '{query}':\n\n" + "\n".join(matches)
                }]
            }
        except Exception as e:
            return {
                "content": [{"type": "text", "text": f"Search error: {e}"}],
                "isError": True
            }
    
    # Resource implementations
    
    def _resource_swe_instances(self) -> Dict[str, Any]:
        """Get SWE-bench instances resource"""
        instances = self._load_swe_instances()
        return {
            "contents": [{
                "uri": "swe-bench://instances",
                "mimeType": "application/json",
                "text": json.dumps(instances, indent=2)
            }]
        }
    
    def _resource_igla_config(self) -> Dict[str, Any]:
        """Get IGLA config resource"""
        config = {
            "phi": PHI,
            "phoenix": PHOENIX,
            "server_name": SERVER_NAME,
            "server_version": SERVER_VERSION,
            "protocol_version": PROTOCOL_VERSION,
            "tools_count": len(self.tools),
            "resources_count": len(self.resources)
        }
        return {
            "contents": [{
                "uri": "igla://config",
                "mimeType": "application/json",
                "text": json.dumps(config, indent=2)
            }]
        }
    
    def _resource_igla_stats(self) -> Dict[str, Any]:
        """Get IGLA stats resource"""
        stats = {
            "modules": {
                "swe_agent": 26,
                "benchmark": 4,
                "llm": 2,
                "mcp": 2,
                "total": 34
            },
            "tests": {
                "swe_agent": 177,
                "benchmark": 61,
                "llm": 29,
                "mcp": 27,
                "total": 294
            },
            "sacred_formula": "φ² + 1/φ² = 3",
            "phoenix": PHOENIX
        }
        return {
            "contents": [{
                "uri": "igla://stats",
                "mimeType": "application/json",
                "text": json.dumps(stats, indent=2)
            }]
        }
    
    def _load_swe_instances(self) -> List[Dict]:
        """Load SWE-bench instances"""
        sample_file = self.data_dir / "sample_instances.json"
        if sample_file.exists():
            with open(sample_file) as f:
                return json.load(f)
        return []
    
    def _success_response(self, request_id: Any, result: Dict[str, Any]) -> Dict[str, Any]:
        """Create success response"""
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": result
        }
    
    def _error_response(self, request_id: Any, code: int, message: str) -> Dict[str, Any]:
        """Create error response"""
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "error": {
                "code": code,
                "message": message
            }
        }
    
    def run_stdio(self):
        """Run server on stdio transport"""
        sys.stderr.write(f"IGLA MCP Server v{SERVER_VERSION} started\n")
        sys.stderr.write(f"φ² + 1/φ² = 3 | PHOENIX = {PHOENIX}\n")
        sys.stderr.flush()
        
        while True:
            try:
                line = sys.stdin.readline()
                if not line:
                    break
                
                request = json.loads(line)
                response = self.handle_request(request)
                
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()
                
            except json.JSONDecodeError as e:
                sys.stderr.write(f"JSON error: {e}\n")
                sys.stderr.flush()
            except Exception as e:
                sys.stderr.write(f"Error: {e}\n")
                sys.stderr.flush()


def main():
    """Main entry point"""
    server = MCPServer()
    server.run_stdio()


if __name__ == "__main__":
    main()
