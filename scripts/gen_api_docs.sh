#!/bin/bash
# VIBEE API Documentation Generator
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

OUTPUT_DIR="docs/api/generated"
mkdir -p "$OUTPUT_DIR"

echo "═══════════════════════════════════════════════════════════════"
echo "  VIBEE API Documentation Generator"
echo "  φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════"

# Generate index
cat > "$OUTPUT_DIR/INDEX.md" << 'EOF'
# VIBEE API Reference

**Auto-generated from .vibee specifications**

## Categories

EOF

# Process each category
for category in core crypto quantum ai codegen pas agents tools; do
  if [ -d "specs/tri/$category" ]; then
    echo "Processing $category..."
    
    # Create category file
    cat > "$OUTPUT_DIR/${category}.md" << EOF
# ${category^} API

**Auto-generated from specs/tri/$category/**

## Types

EOF
    
    # Extract types from each spec
    for spec in specs/tri/$category/*.vibee; do
      if [ -f "$spec" ]; then
        name=$(basename "$spec" .vibee)
        
        # Extract name and version
        spec_name=$(grep "^name:" "$spec" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
        spec_version=$(grep "^version:" "$spec" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' "')
        
        if [ -n "$spec_name" ]; then
          echo "### $spec_name" >> "$OUTPUT_DIR/${category}.md"
          echo "" >> "$OUTPUT_DIR/${category}.md"
          echo "**Version:** $spec_version" >> "$OUTPUT_DIR/${category}.md"
          echo "" >> "$OUTPUT_DIR/${category}.md"
          
          # Extract types section
          if grep -q "^types:" "$spec"; then
            echo "#### Types" >> "$OUTPUT_DIR/${category}.md"
            echo '```yaml' >> "$OUTPUT_DIR/${category}.md"
            sed -n '/^types:/,/^[a-z]/p' "$spec" | head -20 >> "$OUTPUT_DIR/${category}.md"
            echo '```' >> "$OUTPUT_DIR/${category}.md"
            echo "" >> "$OUTPUT_DIR/${category}.md"
          fi
          
          # Extract behaviors section
          if grep -q "^behaviors:" "$spec"; then
            echo "#### Behaviors" >> "$OUTPUT_DIR/${category}.md"
            echo '```yaml' >> "$OUTPUT_DIR/${category}.md"
            sed -n '/^behaviors:/,/^[a-z]/p' "$spec" | head -30 >> "$OUTPUT_DIR/${category}.md"
            echo '```' >> "$OUTPUT_DIR/${category}.md"
            echo "" >> "$OUTPUT_DIR/${category}.md"
          fi
          
          echo "---" >> "$OUTPUT_DIR/${category}.md"
          echo "" >> "$OUTPUT_DIR/${category}.md"
        fi
      fi
    done
    
    # Add to index
    count=$(ls specs/tri/$category/*.vibee 2>/dev/null | wc -l)
    echo "- [${category^}](${category}.md) - $count specifications" >> "$OUTPUT_DIR/INDEX.md"
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Documentation generated in $OUTPUT_DIR"
echo "═══════════════════════════════════════════════════════════════"
