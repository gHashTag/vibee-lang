#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════════
# TRI PARSER - GENERATED FROM ⲧⲣⲓ_ⲡⲁⲣⲥⲉⲣ.tri
# ═══════════════════════════════════════════════════════════════════════════════
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3
# Language: Python
# ═══════════════════════════════════════════════════════════════════════════════

from dataclasses import dataclass, field
from enum import Enum, auto
from typing import List, Dict, Union, Optional, Any
import time
import re

# Sacred Constants
PHI: float = 1.618033988749895
GOLDEN_IDENTITY: float = 3.0

# ═══════════════════════════════════════════════════════════════════════════════
# TOKEN TYPES
# ═══════════════════════════════════════════════════════════════════════════════

class TokenType(Enum):
    IDENT = auto()
    STRING = auto()
    NUMBER = auto()
    COLON = auto()
    DASH = auto()
    INDENT = auto()
    NEWLINE = auto()
    COMMENT = auto()
    LBRACKET = auto()
    RBRACKET = auto()
    LBRACE = auto()
    RBRACE = auto()
    COMMA = auto()
    PIPE = auto()
    EOF = auto()

@dataclass
class Token:
    type: TokenType
    value: str
    line: int
    col: int

# ═══════════════════════════════════════════════════════════════════════════════
# AST NODES
# ═══════════════════════════════════════════════════════════════════════════════

ValueNode = Union[str, float, bool, None, Dict[str, Any], List[Any]]

@dataclass
class MapEntry:
    key: str
    value: ValueNode

@dataclass
class Document:
    entries: List[MapEntry] = field(default_factory=list)

# ═══════════════════════════════════════════════════════════════════════════════
# LEXER
# ═══════════════════════════════════════════════════════════════════════════════

class Lexer:
    def __init__(self, input_str: str):
        self.input = input_str
        self.pos = 0
        self.line = 1
        self.col = 1
    
    def next_token(self) -> Token:
        self._skip_whitespace()
        
        if self.pos >= len(self.input):
            return Token(TokenType.EOF, "", self.line, self.col)
        
        start = self.pos
        start_col = self.col
        c = self.input[self.pos]
        
        # Single character tokens
        single_chars = {
            ':': TokenType.COLON,
            '-': TokenType.DASH,
            '[': TokenType.LBRACKET,
            ']': TokenType.RBRACKET,
            '{': TokenType.LBRACE,
            '}': TokenType.RBRACE,
            ',': TokenType.COMMA,
            '|': TokenType.PIPE,
        }
        
        if c in single_chars:
            self._advance()
            return Token(single_chars[c], c, self.line, start_col)
        
        if c == '\n':
            self._advance()
            self.line += 1
            self.col = 1
            return Token(TokenType.NEWLINE, "\n", self.line - 1, start_col)
        
        if c == '#':
            # Comment
            while self.pos < len(self.input) and self.input[self.pos] != '\n':
                self._advance()
            return Token(TokenType.COMMENT, self.input[start:self.pos], self.line, start_col)
        
        if c == '"':
            # String
            self._advance()  # skip opening quote
            str_start = self.pos
            while self.pos < len(self.input) and self.input[self.pos] != '"':
                self._advance()
            str_end = self.pos
            if self.pos < len(self.input):
                self._advance()  # skip closing quote
            return Token(TokenType.STRING, self.input[str_start:str_end], self.line, start_col)
        
        if c.isdigit():
            # Number
            while self.pos < len(self.input) and (self.input[self.pos].isdigit() or self.input[self.pos] == '.'):
                self._advance()
            return Token(TokenType.NUMBER, self.input[start:self.pos], self.line, start_col)
        
        if self._is_ident_start(c):
            # Identifier
            while self.pos < len(self.input) and self._is_ident_char(self.input[self.pos]):
                self._advance()
            return Token(TokenType.IDENT, self.input[start:self.pos], self.line, start_col)
        
        # Unknown - skip
        self._advance()
        return self.next_token()
    
    def _advance(self):
        if self.pos < len(self.input):
            self.pos += 1
            self.col += 1
    
    def _skip_whitespace(self):
        while self.pos < len(self.input) and self.input[self.pos] in ' \t\r':
            self._advance()
    
    def _is_ident_start(self, c: str) -> bool:
        return c.isalpha() or c == '_' or ord(c) >= 0x80
    
    def _is_ident_char(self, c: str) -> bool:
        return self._is_ident_start(c) or c.isdigit()

# ═══════════════════════════════════════════════════════════════════════════════
# PARSER
# ═══════════════════════════════════════════════════════════════════════════════

class Parser:
    def __init__(self, input_str: str):
        self.lexer = Lexer(input_str)
        self.current = self.lexer.next_token()
        self.bytes_parsed = 0
    
    def parse(self) -> Document:
        doc = Document()
        
        while self.current.type != TokenType.EOF:
            if self.current.type in (TokenType.NEWLINE, TokenType.COMMENT):
                self._advance()
                continue
            
            if self.current.type == TokenType.IDENT:
                key = self.current.value
                self._advance()
                
                if self.current.type == TokenType.COLON:
                    self._advance()
                    self._skip_newlines()
                    value = self._parse_value()
                    doc.entries.append(MapEntry(key, value))
            else:
                self._advance()
        
        self.bytes_parsed = self.lexer.pos
        return doc
    
    def _parse_value(self) -> ValueNode:
        if self.current.type == TokenType.STRING:
            val = self.current.value
            self._advance()
            return val
        
        if self.current.type == TokenType.NUMBER:
            val = float(self.current.value)
            self._advance()
            return val
        
        if self.current.type == TokenType.IDENT:
            val = self.current.value
            self._advance()
            if val == "true":
                return True
            if val == "false":
                return False
            if val == "null":
                return None
            return val
        
        if self.current.type == TokenType.LBRACKET:
            return self._parse_array()
        
        if self.current.type == TokenType.LBRACE:
            return self._parse_inline_map()
        
        return None
    
    def _parse_array(self) -> List[Any]:
        self._advance()  # skip [
        items = []
        
        while self.current.type != TokenType.RBRACKET and self.current.type != TokenType.EOF:
            self._skip_newlines()
            if self.current.type == TokenType.RBRACKET:
                break
            
            item = self._parse_value()
            items.append(item)
            
            if self.current.type == TokenType.COMMA:
                self._advance()
            self._skip_newlines()
        
        if self.current.type == TokenType.RBRACKET:
            self._advance()
        return items
    
    def _parse_inline_map(self) -> Dict[str, Any]:
        self._advance()  # skip {
        result = {}
        
        while self.current.type != TokenType.RBRACE and self.current.type != TokenType.EOF:
            self._skip_newlines()
            if self.current.type == TokenType.RBRACE:
                break
            
            if self.current.type in (TokenType.IDENT, TokenType.STRING):
                key = self.current.value
                self._advance()
                
                if self.current.type == TokenType.COLON:
                    self._advance()
                    value = self._parse_value()
                    result[key] = value
            else:
                self._advance()
            
            if self.current.type == TokenType.COMMA:
                self._advance()
            self._skip_newlines()
        
        if self.current.type == TokenType.RBRACE:
            self._advance()
        return result
    
    def _advance(self):
        self.current = self.lexer.next_token()
    
    def _skip_newlines(self):
        while self.current.type in (TokenType.NEWLINE, TokenType.COMMENT):
            self._advance()

# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARK
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class BenchmarkResult:
    iterations: int
    total_ns: int
    avg_ns: int
    bytes_parsed: int
    mb_per_sec: float

def benchmark(input_str: str, iterations: int = 1000) -> BenchmarkResult:
    total_ns = 0
    total_bytes = 0
    
    for _ in range(iterations):
        start = time.perf_counter_ns()
        parser = Parser(input_str)
        doc = parser.parse()
        end = time.perf_counter_ns()
        
        total_ns += (end - start)
        total_bytes += parser.bytes_parsed
    
    avg_ns = total_ns // iterations
    avg_bytes = total_bytes // iterations
    mb_per_sec = (avg_bytes / avg_ns * 1000) if avg_ns > 0 else 0
    
    return BenchmarkResult(
        iterations=iterations,
        total_ns=total_ns,
        avg_ns=avg_ns,
        bytes_parsed=avg_bytes,
        mb_per_sec=mb_per_sec
    )

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS
# ═══════════════════════════════════════════════════════════════════════════════

def test_golden_identity():
    phi_sq = PHI * PHI
    inv_phi_sq = 1.0 / phi_sq
    assert abs(phi_sq + inv_phi_sq - GOLDEN_IDENTITY) < 0.0001
    print("✓ test_golden_identity passed")

def test_lexer_simple():
    lexer = Lexer('name: "test"')
    
    t1 = lexer.next_token()
    assert t1.type == TokenType.IDENT
    assert t1.value == "name"
    
    t2 = lexer.next_token()
    assert t2.type == TokenType.COLON
    
    t3 = lexer.next_token()
    assert t3.type == TokenType.STRING
    assert t3.value == "test"
    
    print("✓ test_lexer_simple passed")

def test_parser_simple_map():
    parser = Parser('name: "test"\nversion: "1.0"')
    doc = parser.parse()
    
    assert len(doc.entries) == 2
    assert doc.entries[0].key == "name"
    assert doc.entries[0].value == "test"
    
    print("✓ test_parser_simple_map passed")

def test_parser_nested():
    parser = Parser('config: {host: "localhost", port: 8080}')
    doc = parser.parse()
    
    assert len(doc.entries) == 1
    assert doc.entries[0].key == "config"
    assert isinstance(doc.entries[0].value, dict)
    
    print("✓ test_parser_nested passed")

def test_parser_array():
    parser = Parser('items: [1, 2, 3]')
    doc = parser.parse()
    
    assert len(doc.entries) == 1
    assert doc.entries[0].key == "items"
    assert isinstance(doc.entries[0].value, list)
    assert len(doc.entries[0].value) == 3
    
    print("✓ test_parser_array passed")

def test_lexer_coptic():
    lexer = Lexer('ⲛⲁⲙⲉ: "ⲧⲉⲥⲧ"')
    
    t1 = lexer.next_token()
    assert t1.type == TokenType.IDENT
    assert len(t1.value) > 0
    
    print("✓ test_lexer_coptic passed")

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("═" * 70)
    print("  TRI PARSER - PYTHON TESTS")
    print("═" * 70)
    
    test_golden_identity()
    test_lexer_simple()
    test_parser_simple_map()
    test_parser_nested()
    test_parser_array()
    test_lexer_coptic()
    
    print("\n" + "═" * 70)
    print("  BENCHMARK")
    print("═" * 70)
    
    # Generate test data
    test_data = """
name: "test_document"
version: "1.0.0"
config:
  host: "localhost"
  port: 8080
  debug: true
items: [1, 2, 3, 4, 5]
metadata: {author: "zmei", date: "2026-01-18"}
""" * 100  # ~5KB
    
    result = benchmark(test_data, iterations=1000)
    
    print(f"  Input size: {len(test_data)} bytes")
    print(f"  Iterations: {result.iterations}")
    print(f"  Avg time: {result.avg_ns / 1000:.2f} µs")
    print(f"  Speed: {result.mb_per_sec:.2f} MB/s")
    print("═" * 70)
