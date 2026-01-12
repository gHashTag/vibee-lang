#!/usr/bin/env python3
"""
VIBEE Documentation Generator
Generates documentation from honeycomb plugin source files.
Usage: python docs_generator.py generate --all
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any


class DocsGenerator:
    """Generator for VIBEE plugin documentation."""
    
    def __init__(self, docs_dir: str = "docs", honeycomb_dir: str = "honeycomb"):
        self.docs_dir = Path(docs_dir)
        self.honeycomb_dir = Path(honeycomb_dir)
        self.ignored_dirs = {'__pycache__', '.git', 'node_modules'}
        
    def find_plugins(self) -> List[Dict[str, str]]:
        """Find all plugin directories in honeycomb."""
        plugins = []
        
        for category_dir in self.honeycomb_dir.iterdir():
            if category_dir.is_dir() and category_dir.name not in self.ignored_dirs:
                for plugin_dir in category_dir.iterdir():
                    if plugin_dir.is_dir():
                        plugins.append({
                            'category': category_dir.name,
                            'name': plugin_dir.name,
                            'path': str(plugin_dir),
                            'id': f"{category_dir.name}.{plugin_dir.name}"
                        })
        
        return sorted(plugins, key=lambda x: x['id'])
    
    def extract_metadata(self, vibee_file: Path) -> Dict[str, Any]:
        """Extract metadata from .vibee source file."""
        metadata = {
            'name': '',
            'description': '',
            'version': '1.0.0',
            'functions': 0,
            'types': 0,
            'events': 0,
            'commands': 0,
            'depends_on': []
        }
        
        try:
            content = vibee_file.read_text()
            
            # Extract @plugin annotation
            plugin_match = re.search(r'@plugin\s+(?:name\s+["\']([^"\']+)["\'])?', content)
            if plugin_match and plugin_match.group(1):
                metadata['name'] = plugin_match.group(1)
            
            # Extract description
            desc_match = re.search(r'@description\s+["\']([^"\']+)["\']', content)
            if desc_match:
                metadata['description'] = desc_match.group(1)
            
            # Extract version
            version_match = re.search(r'@version\s+([0-9]+\.[0-9]+\.[0-9]+)', content)
            if version_match:
                metadata['version'] = version_match.group(1)
            
            # Count functions (@fn)
            fn_matches = re.findall(r'@fn\s+(\w+)', content)
            metadata['functions'] = len(fn_matches)
            
            # Count types (@type)
            type_matches = re.findall(r'@type\s+(\w+)', content)
            metadata['types'] = len(type_matches)
            
            # Count events (@event)
            event_matches = re.findall(r'@event\s+(\w+)', content)
            metadata['events'] = len(event_matches)
            
            # Count commands (@command)
            cmd_matches = re.findall(r'@command\s+(\w+)', content)
            metadata['commands'] = len(cmd_matches)
            
        except Exception as e:
            print(f"  Warning: Could not parse {vibee_file}: {e}")
        
        return metadata
    
    def generate_readme(self, plugin: Dict, metadata: Dict, version: str = "v16") -> str:
        """Generate README.md for a plugin."""
        deps = ', '.join(metadata.get('depends_on', [])) or 'None'
        plugin_id = plugin.get('id', f"{plugin.get('category', '')}.{plugin.get('name', '')}")
        
        return f"""# {metadata.get('name', plugin.get('name', 'Unknown'))}

{metadata.get('description', 'Plugin documentation')}

## Plugin Info

| Property | Value |
|----------|-------|
| **ID** | `{plugin_id}` |
| **Version** | `{metadata.get('version', '1.0.0')}` |
| **Category** | `{plugin.get('category', 'unknown')}` |
| **Functions** | {metadata.get('functions', 0)} |
| **Types** | {metadata.get('types', 0)} |
| **Events** | {metadata.get('events', 0)} |
| **Commands** | {metadata.get('commands', 0)} |
| **Dependencies** | {deps} |

## Usage

```vibee
import {metadata.get('name', plugin.get('name'))}

let result = {metadata.get('name', plugin.get('name'))}.some_function()
```

## API Reference

See [api.md](api.md) for full API documentation.

## Events

See [events.md](events.md) for event documentation.
"""
    
    def generate_api_doc(self, plugin: Dict, metadata: Dict, version: str = "v16") -> str:
        """Generate api.md for a plugin."""
        plugin_id = plugin.get('id', f"{plugin.get('category', '')}.{plugin.get('name', '')}")
        return f"""# API Reference: {metadata.get('name', plugin.get('name', 'Unknown'))}

This document describes the API surface for `{plugin_id}`.

## Functions

All exported functions in this plugin.

## Types

Custom types defined in this plugin.

## Error Handling

Functions return `Result<T, Error>` types.
"""
    
    def generate_events_doc(self, plugin: Dict, metadata: Dict, version: str = "v16") -> str:
        """Generate events.md for a plugin."""
        plugin_id = plugin.get('id', f"{plugin.get('category', '')}.{plugin.get('name', '')}")
        return f"""# Events Reference: {metadata.get('name', plugin.get('name', 'Unknown'))}

This document describes all events emitted by `{plugin_id}`.

## Event Types

| Event | Payload | Description |
|-------|---------|-------------|
| `init` | `{{}}` | Plugin initialized |
| `ready` | `{{version}}` | Plugin ready |

## Event Handlers

```vibee
on {metadata.get('name', plugin.get('name'))}.event_name as (payload) => {{
  // Handle event
}}
```
"""
    
    def generate_version_index(self, version: str = "v16") -> Dict[str, Any]:
        """Generate index.json for a version."""
        plugins = self.find_plugins()
        
        categories = {}
        for plugin in plugins:
            cat = plugin['category']
            if cat not in categories:
                categories[cat] = []
            
            metadata = self.extract_metadata(
                Path(plugin['path']) / f"{plugin['name']}.vibee"
            )
            
            categories[cat].append({
                'id': plugin['id'],
                'name': metadata.get('name', plugin['name']),
                'description': metadata.get('description', f"{plugin['category']} plugin"),
                'version': metadata.get('version', '1.0.0'),
                'functions': metadata.get('functions', 0),
                'types': metadata.get('types', 0),
                'events': metadata.get('events', 0),
                'commands': metadata.get('commands', 0),
                'depends_on': metadata.get('depends_on', []),
                'path': f"/docs/{version}/{plugin['id']}/README.md"
            })
        
        return {
            'version': version,
            'generated_at': datetime.utcnow().isoformat() + 'Z',
            'total_plugins': len(plugins),
            'categories': categories,
            'categories_list': sorted(categories.keys())
        }
    
    def generate_all(self, version: str = "v16"):
        """Generate all documentation for a version."""
        print(f"Generating documentation for {version}...")
        
        version_dir = self.docs_dir / version
        version_dir.mkdir(parents=True, exist_ok=True)
        
        plugins = self.find_plugins()
        print(f"  Found {len(plugins)} plugins")
        
        for plugin in plugins:
            plugin_dir = version_dir / plugin['id']
            plugin_dir.mkdir(parents=True, exist_ok=True)
            
            vibee_file = Path(plugin['path']) / f"{plugin['name']}.vibee"
            if vibee_file.exists():
                metadata = self.extract_metadata(vibee_file)
            else:
                metadata = {
                    'name': plugin['name'],
                    'description': f"{plugin['category']} plugin",
                    'version': '1.0.0',
                    'functions': 0,
                    'types': 0,
                    'events': 0,
                    'commands': 0,
                    'depends_on': []
                }
            
            (plugin_dir / "README.md").write_text(self.generate_readme(plugin, metadata, version))
            (plugin_dir / "api.md").write_text(self.generate_api_doc(plugin, metadata, version))
            (plugin_dir / "events.md").write_text(self.generate_events_doc(plugin, metadata, version))
            
            print(f"    - {plugin['id']}")
        
        index_data = self.generate_version_index(version)
        (version_dir / "index.json").write_text(
            json.dumps(index_data, indent=2, ensure_ascii=False)
        )
        
        print(f"  Total: {len(plugins)} plugins")
        print(f"Docs generated in {version_dir}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="VIBEE Documentation Generator")
    parser.add_argument('command', choices=['generate', 'list'], help='Command to execute')
    parser.add_argument('--version', default='v16', help='Version to generate docs for')
    parser.add_argument('--all', action='store_true', help='Generate docs for all versions')
    parser.add_argument('--docs-dir', default='docs', help='Output directory for docs')
    parser.add_argument('--honeycomb-dir', default='honeycomb', help='Source directory')
    
    args = parser.parse_args()
    
    generator = DocsGenerator(args.docs_dir, args.honeycomb_dir)
    
    if args.command == 'generate':
        if args.all:
            for version in ['v14', 'v15', 'v16']:
                print(f"\n{'='*50}")
                generator.generate_all(version)
        else:
            generator.generate_all(args.version)
    elif args.command == 'list':
        plugins = generator.find_plugins()
        print(f"Found {len(plugins)} plugins:")
        for plugin in plugins:
            print(f"  - {plugin['id']}")


if __name__ == '__main__':
    main()
