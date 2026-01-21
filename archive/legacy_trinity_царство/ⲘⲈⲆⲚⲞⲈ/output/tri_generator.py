#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════════
# TRI GENERATOR - ГЕНЕРАТОР .tri → .zig
# ═══════════════════════════════════════════════════════════════════════════════
# ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
# ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3
# ═══════════════════════════════════════════════════════════════════════════════

import os
import sys
import re
from pathlib import Path
from tri_parser import Parser, Document, MapEntry

PHI = 1.618033988749895
TRINITY = 3
TRINITY_PRIME = 33
PHOENIX = 999
SPEED_OF_LIGHT = 299792458  # c = 299,792,458 м/с
TRINITY_LIGHT = 3e8         # c ≈ TRINITY × 10⁸

class ZigCodegen:
    def __init__(self):
        self.output = []
        self.indent_level = 0
        self.emitted_constants = set()
        self.emitted_tests = set()
        self.test_counter = 0
    
    def generate(self, doc: Document, source_file: str) -> str:
        self.output = []
        self.emitted_constants = set()
        self.emitted_tests = set()
        self.test_counter = 0
        
        # Header
        self._emit_header(source_file)
        
        # Process entries
        for entry in doc.entries:
            self._process_entry(entry)
        
        return '\n'.join(self.output)
    
    def _emit_header(self, source_file: str):
        self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
        self._emit(f"// GENERATED FROM {source_file}")
        self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
        self._emit("// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q")
        self._emit("// ⲌⲞⲖⲞⲦⲀⲒⲀ ⲒⲆⲈⲚⲦⲒⲬⲚⲞⲤⲦⲒ: φ² + 1/φ² = 3")
        self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
        self._emit("// 🔥 ⲪⲞⲈⲚⲒⲜ ⲂⲖⲈⲤⲤⲒⲚⲄ 🔥")
        self._emit("// Этот модуль благословлён Жар-птицей (PHOENIX = 999 = 3³ × 37)")
        self._emit("// Фазы: ПЕПЕЛ → ИСКРА → ПЛАМЯ → ВОЗРОЖДЕНИЕ")
        self._emit("// Способности: ИСЦЕЛЕНИЕ (1/φ) + ЭВОЛЮЦИЯ (μ = 1/φ²/10)")
        self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
        self._emit("")
        self._emit("const std = @import(\"std\");")
        self._emit("")
        # Always emit PHI constant - required for golden identity test
        self._emit(f"pub const PHI: f64 = {PHI};")
        self._emit("pub const GOLDEN_IDENTITY: f64 = 3.0;")
        self._emit("")
    
    def _process_entry(self, entry: MapEntry):
        key = entry.key
        value = entry.value
        
        # ⲥⲁⲕⲣⲁ_ⲕⲟⲛⲥⲧⲁⲛⲧⲥ → pub const
        if 'ⲥⲁⲕⲣⲁ' in key or 'ⲕⲟⲛⲥⲧⲁⲛⲧⲥ' in key:
            self._emit_sacred_constants(value)
            return
        
        # ⲥⲧⲣⲩⲕⲧ → struct
        if 'ⲥⲧⲣⲩⲕⲧ' in key or '_ⲛⲟⲇⲉ' in key:
            self._emit_struct(key, value)
            return
        
        # ⲉⲛⲩⲙ or ⲧⲓⲡⲩ → enum
        if 'ⲉⲛⲩⲙ' in key or 'ⲧⲓⲡⲩ' in key or 'ⲧⲟⲕⲉⲛ' in key:
            self._emit_enum(key, value)
            return
        
        # ⲃⲉⲏⲁⲃⲓⲟⲣⲥ → functions
        if 'ⲃⲉⲏⲁⲃⲓⲟⲣⲥ' in key:
            self._emit_behaviors(value)
            return
        
        # ⲧⲉⲥⲧ_ⲕⲁⲥⲉⲥ → tests
        if 'ⲧⲉⲥⲧ' in key:
            self._emit_tests(value)
            return
        
        # Default: emit as comment
        self._emit(f"// {key}")
    
    def _emit_sacred_constants(self, value):
        if 'sacred_emitted' not in self.emitted_constants:
            self.emitted_constants.add('sacred_emitted')
            self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
            self._emit("// ⲤⲀⲔⲢⲀ ⲔⲞⲚⲤⲦⲀⲚⲦⲤ")
            self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
            self._emit("")
            # PHI and GOLDEN_IDENTITY already emitted in header
            self._emit(f"pub const TRINITY: usize = {TRINITY};")
            self._emit(f"pub const TRINITY_PRIME: usize = {TRINITY_PRIME};")
            self._emit(f"pub const PHOENIX: usize = {PHOENIX};")
            self._emit("")
            self._emit("// 🔥 Phoenix Flight Parameters")
            self._emit(f"pub const FLIGHT_SPEED: f64 = {PHI};")
            self._emit(f"pub const HEALING_POWER: f64 = {1.0/PHI};")
            self._emit(f"pub const EVOLUTION_RATE: f64 = {1.0/(PHI*PHI)/10};")
            self._emit("")
            self._emit("// ⚡ Speed of Light - TRINITY × 10⁸")
            self._emit(f"pub const SPEED_OF_LIGHT: u64 = {SPEED_OF_LIGHT}; // c = 299,792,458 м/с")
            self._emit(f"pub const TRINITY_LIGHT: f64 = {TRINITY_LIGHT}; // c ≈ 3 × 10⁸")
            self._emit(f"pub const PHOENIX_LIGHT_SPEED: f64 = {SPEED_OF_LIGHT} * {PHI}; // c × φ")
            self._emit("")
            self.emitted_constants.add('PHI')
            self.emitted_constants.add('GOLDEN_IDENTITY')
            self.emitted_constants.add('TRINITY')
            self.emitted_constants.add('TRINITY_PRIME')
            self.emitted_constants.add('PHOENIX')
            self.emitted_constants.add('FLIGHT_SPEED')
            self.emitted_constants.add('HEALING_POWER')
            self.emitted_constants.add('EVOLUTION_RATE')
        
        # Process custom constants from value
        if isinstance(value, dict):
            for k, v in value.items():
                zig_name = self._to_zig_name(k)
                if not zig_name or zig_name in self.emitted_constants:
                    continue
                self.emitted_constants.add(zig_name)
                if isinstance(v, float):
                    self._emit(f"pub const {zig_name}: f64 = {v};")
                elif isinstance(v, int):
                    self._emit(f"pub const {zig_name}: usize = {v};")
            self._emit("")
    
    def _emit_struct(self, name: str, value):
        zig_name = self._to_zig_name(name)
        if not zig_name or zig_name in self.emitted_constants:
            return
        self.emitted_constants.add(zig_name)
        
        self._emit(f"pub const {zig_name} = struct {{")
        self.indent_level += 1
        
        emitted_fields = set()
        if isinstance(value, dict):
            for field_name, field_type in value.items():
                zig_field = self._to_zig_name(field_name)
                if not zig_field or zig_field in emitted_fields:
                    continue
                emitted_fields.add(zig_field)
                zig_type = self._to_zig_type(field_type)
                self._emit_indent(f"{zig_field}: {zig_type},")
        
        self._emit("")
        self._emit_indent(f"pub fn init() {zig_name} {{")
        self.indent_level += 1
        self._emit_indent("return .{")
        self.indent_level += 1
        emitted_fields2 = set()
        if isinstance(value, dict):
            for field_name, field_type in value.items():
                zig_field = self._to_zig_name(field_name)
                if not zig_field or zig_field in emitted_fields2:
                    continue
                emitted_fields2.add(zig_field)
                default = self._default_value(field_type)
                self._emit_indent(f".{zig_field} = {default},")
        self.indent_level -= 1
        self._emit_indent("};")
        self.indent_level -= 1
        self._emit_indent("}")
        
        self.indent_level -= 1
        self._emit("};")
        self._emit("")
    
    def _emit_enum(self, name: str, value):
        zig_name = self._to_zig_name(name)
        if not zig_name or zig_name in self.emitted_constants:
            return
        self.emitted_constants.add(zig_name)
        
        self._emit(f"pub const {zig_name} = enum(u8) {{")
        self.indent_level += 1
        
        emitted_variants = set()
        if isinstance(value, list):
            for i, variant in enumerate(value):
                zig_variant = self._to_zig_name(str(variant))
                if not zig_variant or zig_variant in emitted_variants:
                    zig_variant = f"variant_{i}"
                emitted_variants.add(zig_variant)
                self._emit_indent(f"{zig_variant} = {i},")
        
        self.indent_level -= 1
        self._emit("};")
        self._emit("")
    
    def _emit_behaviors(self, value):
        if 'behaviors_header' in self.emitted_constants:
            return
        self.emitted_constants.add('behaviors_header')
        
        self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
        self._emit("// ⲂⲈⲎⲀⲂⲒⲞⲢⲤ")
        self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
        self._emit("")
        
        func_counter = 0
        if isinstance(value, list):
            for behavior in value:
                if isinstance(behavior, dict):
                    name = behavior.get('ⲟⲛⲟⲙⲁ', f'behavior_{func_counter}')
                    zig_name = self._to_zig_name(name)
                    if not zig_name:
                        zig_name = f'behavior_{func_counter}'
                    if zig_name in self.emitted_constants:
                        zig_name = f'{zig_name}_{func_counter}'
                    self.emitted_constants.add(zig_name)
                    func_counter += 1
                    self._emit(f"pub fn {zig_name}() void {{")
                    self._emit("    // TODO: implement from .tri spec")
                    self._emit("}")
                    self._emit("")
    
    def _emit_tests(self, value):
        if 'tests_header' not in self.emitted_tests:
            self.emitted_tests.add('tests_header')
            self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
            self._emit("// ⲦⲈⲤⲦⲤ")
            self._emit("// ═══════════════════════════════════════════════════════════════════════════════")
            self._emit("")
            
            # Golden identity test
            self._emit('test "ⲍⲟⲗⲟⲧⲁⲓⲁ_ⲓⲇⲉⲛⲧⲓⲭⲛⲟⲥⲧⲓ" {')
            self._emit("    const phi_sq = PHI * PHI;")
            self._emit("    const inv_phi_sq = 1.0 / phi_sq;")
            self._emit("    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);")
            self._emit("}")
            self._emit("")
        
        if isinstance(value, list):
            for test_case in value:
                if isinstance(test_case, dict):
                    name = test_case.get('ⲟⲛⲟⲙⲁ', f'test_{self.test_counter}')
                    self.test_counter += 1
                    zig_name = self._to_zig_name(name)
                    if not zig_name or zig_name == 'unnamed':
                        zig_name = f'test_{self.test_counter}'
                    if zig_name in self.emitted_tests:
                        zig_name = f'{zig_name}_{self.test_counter}'
                    self.emitted_tests.add(zig_name)
                    self._emit(f'test "{zig_name}" {{')
                    self._emit("    // TODO: implement from .tri spec")
                    self._emit("}")
                    self._emit("")
    
    def _to_zig_name(self, coptic_name: str) -> str:
        """Convert Coptic name to valid Zig identifier"""
        if not coptic_name:
            return ''
        
        # Replace Coptic characters with ASCII equivalents
        result = []
        for c in coptic_name:
            if c.isascii() and (c.isalnum() or c == '_'):
                result.append(c)
            elif ord(c) >= 0x2C80:  # Coptic range
                result.append('_')
        
        name = ''.join(result)
        # Remove consecutive underscores
        while '__' in name:
            name = name.replace('__', '_')
        # Remove leading/trailing underscores
        name = name.strip('_')
        
        # Return empty if only underscores
        return name if name and name != '_' else ''
    
    def _to_zig_type(self, tri_type) -> str:
        """Convert .tri type to Zig type"""
        if isinstance(tri_type, str):
            type_map = {
                'ⲥⲧⲣⲟⲕⲁ': '[]const u8',
                'ⲭⲓⲥⲗⲟ': 'u64',
                'ⲫⲗⲟⲁⲧ': 'f64',
                'ⲃⲩⲗ': 'bool',
                'ⲙⲁⲥⲥⲓⲃ': '[]const u8',
            }
            for coptic, zig in type_map.items():
                if coptic in tri_type:
                    return zig
            return '[]const u8'
        return 'void'
    
    def _default_value(self, tri_type) -> str:
        """Get default value for type"""
        if isinstance(tri_type, str):
            if 'ⲭⲓⲥⲗⲟ' in tri_type:
                return '0'
            if 'ⲫⲗⲟⲁⲧ' in tri_type:
                return '0.0'
            if 'ⲃⲩⲗ' in tri_type:
                return 'false'
        return '""'
    
    def _emit(self, line: str):
        self.output.append(line)
    
    def _emit_indent(self, line: str):
        indent = "    " * self.indent_level
        self.output.append(f"{indent}{line}")


class Generator:
    def __init__(self, input_dir: str, output_dir: str):
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.files_generated = 0
    
    def generate_all(self):
        """Generate .zig files from all .tri files"""
        for tri_file in self.input_dir.glob("*.tri"):
            self.generate_file(tri_file)
    
    def generate_file(self, tri_file: Path):
        """Generate .zig from single .tri file"""
        print(f"Processing: {tri_file.name}")
        
        # Read .tri file
        content = tri_file.read_text(encoding='utf-8')
        
        # Parse
        parser = Parser(content)
        doc = parser.parse()
        
        # Generate
        codegen = ZigCodegen()
        output = codegen.generate(doc, tri_file.name)
        
        # Write .zig file
        output_file = self.output_dir / f"{tri_file.stem}.zig"
        output_file.write_text(output, encoding='utf-8')
        
        self.files_generated += 1
        print(f"  → Generated: {output_file.name}")


def main():
    input_dir = sys.argv[1] if len(sys.argv) > 1 else ".."
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "."
    
    print("═" * 70)
    print("  TRI GENERATOR - .tri → .zig")
    print("  ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q")
    print("═" * 70)
    
    generator = Generator(input_dir, output_dir)
    generator.generate_all()
    
    print("═" * 70)
    print(f"  Generated {generator.files_generated} files")
    print("═" * 70)


if __name__ == "__main__":
    main()
