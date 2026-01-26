#!/usr/bin/env python3
"""
py2vibee - Convert Python code to .vibee specifications
φ² + 1/φ² = 3 | PHOENIX = 999

Usage:
  py2vibee <input.py> --target <language> --output <output.vibee>
  py2vibee --help

Supported targets: varlog, verilog, zig, python, rust, go
"""

import argparse
import ast
import sys
import os
import yaml
from typing import Dict, List, Any, Optional, Tuple
import textwrap

# Sacred constants
PHI = 1.618033988749895
TRINITY = 3.0
PHOENIX = 999

class Py2Vibee:
    """Convert Python code to VIBEE specifications"""
    
    def __init__(self):
        self.type_map = {
            'int': 'Int',
            'float': 'Float', 
            'str': 'String',
            'bool': 'Bool',
            'list': 'List',
            'dict': 'Map',
            'tuple': 'Tuple',
            'None': 'Void'
        }
        
        self.default_constants = {
            'CLOCK_FREQ': 50000000,
            'MAX_VALUE': 255,
            'MIN_VALUE': 0
        }
    
    def parse_python_file(self, filepath: str) -> ast.Module:
        """Parse Python file into AST"""
        with open(filepath, 'r') as f:
            content = f.read()
        return ast.parse(content, filename=filepath)
    
    def extract_functions(self, node: ast.Module) -> List[Dict[str, Any]]:
        """Extract function definitions from AST"""
        functions = []
        
        for item in node.body:
            if isinstance(item, ast.FunctionDef):
                func_info = {
                    'name': item.name,
                    'args': [],
                    'returns': None,
                    'docstring': ast.get_docstring(item),
                    'body_lines': len(item.body) if item.body else 0
                }
                
                # Parse arguments
                for arg in item.args.args:
                    arg_type = self._infer_type_from_arg(arg)
                    func_info['args'].append({
                        'name': arg.arg,
                        'type': arg_type
                    })
                
                # Parse return annotation
                if item.returns:
                    func_info['returns'] = self._parse_type_annotation(item.returns)
                
                functions.append(func_info)
        
        return functions
    
    def _infer_type_from_name(self, name: str) -> str:
        """Infer VIBEE type from Python variable name"""
        name_lower = name.lower()
        
        if any(word in name_lower for word in ['count', 'index', 'value', 'num', 'size', 'width', 'height']):
            return 'Int'
        elif any(word in name_lower for word in ['name', 'text', 'msg', 'str', 'string']):
            return 'String'
        elif any(word in name_lower for word in ['flag', 'enable', 'disable', 'active', 'valid', 'ready', 'bool', 'true', 'false']):
            return 'Bool'
        elif any(word in name_lower for word in ['data', 'input', 'output', 'result']):
            return 'Int'  # Default for generic data
        else:
            return 'Int'  # Default
    
    def _infer_type_from_arg(self, arg_node) -> str:
        """Infer type from AST arg node, checking annotation if available"""
        # Check if arg has annotation
        if hasattr(arg_node, 'annotation') and arg_node.annotation:
            return self._parse_type_annotation(arg_node.annotation)
        
        # Fall back to name inference
        return self._infer_type_from_name(arg_node.arg)
    
    def _parse_type_annotation(self, node) -> str:
        """Parse Python type annotation to VIBEE type"""
        if isinstance(node, ast.Name):
            py_type = node.id
            return self.type_map.get(py_type, 'Int')
        elif isinstance(node, ast.Subscript):
            # Handle List[T], Dict[K, V], etc.
            if isinstance(node.value, ast.Name):
                container = node.value.id
                if container == 'List':
                    return 'List'
                elif container == 'Dict':
                    return 'Map'
        elif isinstance(node, ast.Constant) and node.value is None:
            return 'Void'
        
        return 'Int'  # Default
    
    def generate_vibee_spec(self, 
                           functions: List[Dict[str, Any]], 
                           filename: str,
                           target_language: str = 'varlog',
                           module_name: Optional[str] = None) -> Dict[str, Any]:
        """Generate VIBEE specification from extracted functions"""
        
        if module_name is None:
            module_name = os.path.splitext(os.path.basename(filename))[0]
        
        # Base specification structure
        spec = {
            'name': module_name,
            'version': '1.0.0',
            'language': target_language,
            'module': module_name,
            'description': f'Generated from {filename} by py2vibee',
            'sacred_formula': f'φ² + 1/φ² = {TRINITY}',
            'phoenix': PHOENIX
        }
        
        # Add constants
        spec['constants'] = self.default_constants.copy()
        
        # Generate types from function signatures
        types = {}
        behaviors = []
        
        for func in functions:
            # Create input type for function
            if func['args']:
                type_name = f"{func['name'].title()}Input"
                fields = {}
                for arg in func['args']:
                    fields[arg['name']] = arg['type']
                
                types[type_name] = {
                    'description': f'Input for {func["name"]} function',
                    'fields': fields
                }
            
            # Create behavior
            behavior = {
                'name': func['name'],
                'given': f'Input {", ".join([arg["name"] for arg in func["args"]])}',
                'when': 'Function is called',
                'then': f'Returns {func["returns"] or "result"}'
            }
            
            if func['args']:
                behavior['params'] = [
                    {'name': arg['name'], 'type': arg['type']}
                    for arg in func['args']
                ]
            
            if func['returns']:
                behavior['returns'] = func['returns']
            
            behaviors.append(behavior)
        
        if types:
            spec['types'] = types
        
        spec['behaviors'] = behaviors
        
        # Add hardware-specific sections for Verilog targets
        if target_language in ['varlog', 'verilog']:
            spec['signals'] = self._generate_hardware_signals(functions)
            spec['fsm'] = self._generate_fsm(functions)
        
        return spec
    
    def _generate_hardware_signals(self, functions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Generate hardware signals for Verilog targets"""
        signals = [
            {'name': 'clk', 'width': 1, 'direction': 'input'},
            {'name': 'rst_n', 'width': 1, 'direction': 'input'},
            {'name': 'enable', 'width': 1, 'direction': 'input', 'default': 0},
            {'name': 'done', 'width': 1, 'direction': 'output'},
            {'name': 'error', 'width': 1, 'direction': 'output'}
        ]
        
        # Add function-specific signals
        for func in functions:
            for arg in func['args']:
                signals.append({
                    'name': f'{func["name"]}_{arg["name"]}',
                    'width': self._type_to_width(arg['type']),
                    'direction': 'input'
                })
            
            # Add output signal
            if func['returns'] and func['returns'] != 'Void':
                signals.append({
                    'name': f'{func["name"]}_result',
                    'width': self._type_to_width(func['returns']),
                    'direction': 'output'
                })
        
        return signals
    
    def _type_to_width(self, type_str: str) -> int:
        """Convert VIBEE type to bit width"""
        width_map = {
            'Bool': 1,
            'Int': 32,
            'Float': 32,
            'String': 8,  # Pointer/address width
            'List': 32,
            'Map': 32,
            'Void': 0
        }
        return width_map.get(type_str, 32)
    
    def _generate_fsm(self, functions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Generate FSM for Verilog targets"""
        if not functions:
            return []
        
        states = ['IDLE', 'PROCESSING', 'DONE', 'ERROR']
        
        fsm = {
            'name': f"{functions[0]['name'].title()}FSM",
            'initial': 'IDLE',
            'encoding': 'onehot',
            'states': states,
            'transitions': [
                {'from': 'IDLE', 'to': 'PROCESSING', 'condition': 'enable == 1'},
                {'from': 'PROCESSING', 'to': 'DONE', 'condition': 'done == 1'},
                {'from': 'PROCESSING', 'to': 'ERROR', 'condition': 'error == 1'},
                {'from': ['DONE', 'ERROR'], 'to': 'IDLE', 'condition': 'rst_n == 0'}
            ]
        }
        
        return [fsm]
    
    def save_yaml(self, spec: Dict[str, Any], output_path: str):
        """Save specification as YAML file"""
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        
        with open(output_path, 'w') as f:
            # Write header comment
            f.write(f"# Generated by py2vibee from Python source\n")
            f.write(f"# Sacred Formula: φ² + 1/φ² = {TRINITY}\n")
            f.write(f"# Golden Identity verified | PHOENIX = {PHOENIX}\n")
            f.write(f"# DO NOT EDIT - This file is auto-generated\n")
            f.write("\n")
            
            # Write YAML content
            yaml.dump(spec, f, default_flow_style=False, sort_keys=False, width=80)
    
    def convert(self, input_file: str, output_file: str, target: str = 'varlog'):
        """Main conversion method"""
        try:
            # Parse Python file
            ast_node = self.parse_python_file(input_file)
            
            # Extract functions
            functions = self.extract_functions(ast_node)
            
            if not functions:
                print(f"Warning: No functions found in {input_file}")
                # Create minimal spec
                functions = [{
                    'name': 'process',
                    'args': [],
                    'returns': 'Void',
                    'docstring': None,
                    'body_lines': 0
                }]
            
            # Generate specification
            spec = self.generate_vibee_spec(
                functions=functions,
                filename=input_file,
                target_language=target
            )
            
            # Save to file
            self.save_yaml(spec, output_file)
            
            print(f"✅ Successfully generated {output_file}")
            print(f"   Target: {target}")
            print(f"   Functions: {len(functions)}")
            print(f"   Module: {spec['name']}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error: {e}")
            import traceback
            traceback.print_exc()
            return False


def main():
    parser = argparse.ArgumentParser(
        description='Convert Python code to .vibee specifications',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""
            Examples:
              py2vibee adder.py --target varlog --output adder.vibee
              py2vibee counter.py --target verilog --output counter.vibee
              py2vibee module.py --target zig --output module.vibee
            
            Supported targets: varlog, verilog, zig, python, rust, go
            
            Sacred Formula: φ² + 1/φ² = 3 | PHOENIX = 999
        """)
    )
    
    parser.add_argument('input', help='Input Python file')
    parser.add_argument('--target', '-t', default='varlog',
                       choices=['varlog', 'verilog', 'zig', 'python', 'rust', 'go'],
                       help='Target language (default: varlog)')
    parser.add_argument('--output', '-o', help='Output .vibee file')
    parser.add_argument('--module', '-m', help='Module name (default: derived from filename)')
    
    args = parser.parse_args()
    
    # Set default output filename if not provided
    if not args.output:
        base_name = os.path.splitext(args.input)[0]
        args.output = f"{base_name}.vibee"
    
    # Run conversion
    converter = Py2Vibee()
    success = converter.convert(args.input, args.output, args.target)
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()