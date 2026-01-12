#!/usr/bin/env python3
"""
VIBEE Language Server Protocol (LSP) Server
Provides IDE features: autocomplete, diagnostics, hover, etc.
"""

import json
import sys
import re
from typing import Optional

class VibeeLanguageServer:
    def __init__(self):
        self.documents = {}
        
    def handle_request(self, method: str, params: dict) -> Optional[dict]:
        handlers = {
            "initialize": self.handle_initialize,
            "textDocument/didOpen": self.handle_did_open,
            "textDocument/didChange": self.handle_did_change,
            "textDocument/hover": self.handle_hover,
            "textDocument/completion": self.handle_completion,
            "textDocument/codeAction": self.handle_code_action,
        }
        
        handler = handlers.get(method)
        return handler(params) if handler else None
    
    def handle_initialize(self, params: dict) -> dict:
        return {
            "capabilities": {
                "hoverProvider": True,
                "completionProvider": {"triggerCharacters": [".", " ", "("]},
                "codeActionProvider": True,
                "diagnosticProvider": True,
            },
            "serverInfo": {"name": "VIBEE LSP", "version": "1.0.0"}
        }
    
    def handle_did_open(self, params: dict) -> None:
        uri = params.get("textDocument", {}).get("uri")
        text = params.get("textDocument", {}).get("text", "")
        self.documents[uri] = text
    
    def handle_did_change(self, params: dict) -> None:
        uri = params.get("textDocument", {}).get("uri")
        changes = params.get("contentChanges", [{}])[0]
        self.documents[uri] = changes.get("text", "")
    
    def handle_hover(self, params: dict) -> Optional[dict]:
        # Return hover info for VIBEE keywords
        uri = params.get("textDocument", {}).get("uri")
        pos = params.get("position", {})
        
        word = self._get_word_at(uri, pos)
        hover_info = self._get_hover(word)
        
        if hover_info:
            return {"contents": {"language": "vibee", "value": hover_info}}
        return None
    
    def handle_completion(self, params: dict) -> list:
        uri = params.get("textDocument", {}).get("uri")
        pos = params.get("position", {})
        
        word = self._get_word_at(uri, pos)
        return self._get_completions(word)
    
    def handle_code_action(self, params: dict) -> list:
        uri = params.get("textDocument", {}).get("uri")
        range = params.get("range", {})
        context = params.get("context", {})
        
        actions = []
        for diagnostic in context.get("diagnostics", []):
            code = diagnostic.get("code", "")
            if code in ["VIBEE-V001", "VIBEE-V002", "VIBEE-V003"]:
                actions.append({
                    "title": "Auto-fix",
                    "kind": "quickfix",
                    "edit": {"changes": {uri: [{
                        "range": diagnostic.get("range", {}),
                        "newText": self._get_fix(code)
                    }]}}
                })
        return actions
    
    def _get_word_at(self, uri: str, pos: dict) -> str:
        text = self.documents.get(uri, "")
        line = pos.get("line", 0)
        char = pos.get("character", 0)
        
        lines = text.split("\n")
        if line < len(lines):
            line_text = lines[line]
            if char < len(line_text):
                start = line_text.rfind(" ", 0, char) + 1
                end = line_text.find(" ", char)
                if end == -1:
                    end = len(line_text)
                return line_text[start:end]
        return ""
    
    def _get_hover(self, word: str) -> Optional[str]:
        hover_map = {
            "return": "**return** is forbidden. Use implicit return.",
            "fn": "**fn** keyword is only for lambdas. Use `name(args) { }` for functions.",
            "use": "**use ... in** is deprecated. Use `let` with pipeline.",
            "case": "**case ... of** is deprecated. Use `case ... {`.",
            "pipe": "**pipe (|>)** passes value to next function.",
            "Some": "**Some(x)** is a wrapper. Use `x` directly.",
        }
        return hover_map.get(word)
    
    def _get_completions(self, prefix: str) -> list:
        completions = [
            {"label": "pipe", "detail": "x |> fn", "insertText": "|>$1"},
            {"label": "lambda", "detail": "fn(x) { }", "insertText": "fn($1) { $0 }"},
            {"label": "let", "detail": "let x = value", "insertText": "let $1 = $0"},
        ]
        return [c for c in completions if c["label"].startswith(prefix)] if prefix else completions
    
    def _get_fix(self, code: str) -> str:
        fixes = {
            "VIBEE-V001": "",
            "VIBEE-V002": "",
            "VIBEE-V003": "let ",
        }
        return fixes.get(code, "")

def main():
    server = VibeeLanguageServer()
    
    for line in sys.stdin:
        try:
            request = json.loads(line)
            method = request.get("method")
            params = request.get("params", {})
            
            result = server.handle_request(method, params)
            
            if result is not None:
                response = json.dumps({"id": request.get("id"), "result": result})
                print(response)
                sys.stdout.flush()
        except json.JSONDecodeError:
            pass

if __name__ == "__main__":
    main()
